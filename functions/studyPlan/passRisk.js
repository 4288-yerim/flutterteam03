const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const tf = require("@tensorflow/tfjs");
const fs = require("fs");
const path = require("path");

const db = admin.firestore();

const QNET_SERVICE_KEY = defineSecret("QNET_SERVICE_KEY");

function nodeFileIOHandler(modelJsonPath) {
  return {
    async load() {
      const modelDir = path.dirname(modelJsonPath);
      const modelJSON = JSON.parse(fs.readFileSync(modelJsonPath, 'utf8'));

      const weightSpecs = [];
      const buffers = [];
      for (const group of modelJSON.weightsManifest) {
        weightSpecs.push(...group.weights);
        for (const p of group.paths) {
          buffers.push(fs.readFileSync(path.join(modelDir, p)));
        }
      }

      const concatBuffer = Buffer.concat(buffers);
      const weightData = concatBuffer.buffer.slice(
        concatBuffer.byteOffset,
        concatBuffer.byteOffset + concatBuffer.byteLength
      );

      return {
        modelTopology: modelJSON.modelTopology,
        weightSpecs,
        weightData,
        format: modelJSON.format,
        generatedBy: modelJSON.generatedBy,
        convertedBy: modelJSON.convertedBy,
        userDefinedMetadata: modelJSON.userDefinedMetadata,
      };
    },
  };
}

let model;
async function loadModel() {
  if (!model) {
    // NOTE: tfjs_model 폴더를 functions/studyPlan/tfjs_model 로 옮겨야 합니다.
    const modelJsonPath = path.join(__dirname, 'tfjs_model/model.json');
    model = await tf.loadGraphModel(nodeFileIOHandler(modelJsonPath));
  }
  return model;
}

const FEATURE_MIN = [
  -0.1575008, 0.150032, 0.1500121, 0.0,
  0.000015765891, 0.0055865920, 0.1000188, 0.0000013657623,
];
const FEATURE_MAX = [
  0.6882366, 0.94997954, 0.949982, 4.0,
  0.999983, 0.89928055, 0.99998575, 0.59990424,
];

function normalize(rawFeatures) {
  return rawFeatures.map((v, i) => {
    const range = FEATURE_MAX[i] - FEATURE_MIN[i];
    const normalized = (v - FEATURE_MIN[i]) / range;
    return Math.min(1, Math.max(0, normalized));
  });
}

function parseStepDate(dayLabel, recommendedStartDate, fallbackIndex) {
  const match = /(\d{1,2})\/(\d{1,2})/.exec(dayLabel || '');
  if (!match) {
    const d = new Date(recommendedStartDate);
    d.setDate(d.getDate() + fallbackIndex);
    return d;
  }
  const month = parseInt(match[1], 10);
  const day = parseInt(match[2], 10);
  let year = recommendedStartDate.getFullYear();
  if (month < recommendedStartDate.getMonth() + 1) year += 1;
  return new Date(year, month - 1, day);
}

const GRADE_TO_GRDCD = {
  '기술사': '10',
  '기능장': '20',
  '기사': '30',
  '산업기사': '31',
  '1급': '32',
  '2급': '33',
  '기능사': '40',
};

const GRADE_DIFFICULTY_FALLBACK = {
  '기능사': 0.3,
  '산업기사': 0.5,
  '기사': 0.55,
  '기능장': 0.75,
  '기술사': 0.85,
};

function fallbackDifficultyByGrade(cert) {
  const grade = cert.seriesnm;
  if (grade && GRADE_DIFFICULTY_FALLBACK[grade] != null) {
    return GRADE_DIFFICULTY_FALLBACK[grade];
  }
  return 0.5;
}

async function fetchPassRateFromApi(cert) {
  const grdCd = GRADE_TO_GRDCD[cert.seriesnm];
  if (!grdCd) return null;

  const url = 'http://openapi.q-net.or.kr/api/service/rest/InquiryQualPassRateSVC/getList';
  const baseYY = new Date().getFullYear() - 1;

  const { data } = await axios.get(url, {
    params: {
      ServiceKey: QNET_SERVICE_KEY.value(),
      grdCd,
      baseYY,
      numOfRows: 1000,
      pageNo: 1,
    },
    timeout: 8000,
  });

  const items = data?.response?.body?.items?.item;
  if (!items) return null;
  const itemArr = Array.isArray(items) ? items : [items];

  const matched = itemArr.filter((i) => i.jmFldNm === cert.jmfldnm);
  if (matched.length === 0) return null;

  let totalApplied = 0;
  let totalPassed = 0;
  for (const item of matched) {
    totalApplied += Number(item.recptNoCnt || 0);
    totalPassed += Number(item.examPassCnt || 0);
  }
  if (!totalApplied) return null;

  return (totalPassed / totalApplied) * 100;
}

async function getDifficultyNorm(certificateId) {
  const ref = db.collection('certifications').doc(certificateId);
  const snap = await ref.get();
  if (!snap.exists) return 0.5;

  const cert = snap.data();
  const ONE_MONTH = 30 * 24 * 60 * 60 * 1000;

  if (cert.difficultyNorm != null && cert.difficultyUpdatedAt) {
    const age = Date.now() - cert.difficultyUpdatedAt.toDate().getTime();
    if (age < ONE_MONTH) return cert.difficultyNorm;
  }

  try {
    const passRate = await fetchPassRateFromApi(cert);
    if (passRate == null) return fallbackDifficultyByGrade(cert);

    const difficultyNorm = Math.min(1, Math.max(0, 1 - passRate / 100));

    await ref.update({
      passRate,
      difficultyNorm,
      difficultyUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return difficultyNorm;
  } catch (e) {
    console.error('합격률 API 호출 실패:', e.message);
    return fallbackDifficultyByGrade(cert);
  }
}

async function computeFeatures(uid, certificateName) {
  const planSnap = await db.collection('users').doc(uid)
    .collection('studyPlans')
    .orderBy('createdAt', 'desc')
    .limit(20)
    .get();

  const matchedDoc = planSnap.docs.find((doc) => {
    const d = doc.data();
    return d.certificateName === certificateName && Array.isArray(d.steps);
  });

  if (!matchedDoc) {
    throw new HttpsError('not-found', '해당 자격증의 AI 학습 플랜을 찾을 수 없습니다.');
  }

  const plan = matchedDoc.data();
  const steps = Array.isArray(plan.steps) ? plan.steps : [];
  if (steps.length === 0) {
    throw new HttpsError('failed-precondition', '학습 플랜에 단계가 없습니다.');
  }

  const recommendedStartDate = plan.recommendedStudyStartDate
    ? new Date(plan.recommendedStudyStartDate + 'T00:00:00')
    : new Date();

  const nowKst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const today = new Date(
    nowKst.getUTCFullYear(),
    nowKst.getUTCMonth(),
    nowKst.getUTCDate()
  );
  const stepDates = steps.map((s, i) => parseStepDate(s.dayLabel, new Date(recommendedStartDate), i));

  const totalSteps = steps.length;
  const elapsedSteps = Math.min(
    totalSteps,
    Math.max(0, stepDates.filter((d) => d <= today).length)
  );

  const completedStepCount = steps.filter((s) => s.isCompleted === true).length;
  const completionRate = totalSteps > 0 ? completedStepCount / totalSteps : 0;

  const examDate = plan.examStartAt ? plan.examStartAt.toDate() : null;

  const totalCalendarDays = examDate
    ? Math.max(1, Math.round((examDate - recommendedStartDate) / (1000 * 60 * 60 * 24)))
    : totalSteps;

  const elapsedCalendarDays = Math.min(
    totalCalendarDays,
    Math.max(0, Math.round((today - recommendedStartDate) / (1000 * 60 * 60 * 24)))
  );

  const elapsedRatio = totalCalendarDays > 0 ? elapsedCalendarDays / totalCalendarDays : 0;
  const progressGap = elapsedRatio - completionRate;

  const daysRemaining = examDate
    ? Math.max(0, Math.round((examDate - today) / (1000 * 60 * 60 * 24)))
    : Math.max(1, totalCalendarDays - elapsedCalendarDays);
  const daysRemainingNorm = totalCalendarDays > 0
    ? Math.max(0, daysRemaining / totalCalendarDays)
    : 0;

// completedAt이 있으면 그 값을, 없으면 null (아직 미완료)
function toDateOnly(ts) {
  if (!ts) return null;
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return new Date(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate());
}
const completedDates = steps.map((s) => toDateOnly(s.completedAt));

const sevenDaysAgo = new Date(today); sevenDaysAgo.setDate(today.getDate() - 7);
const recentIdx = steps.map((_, i) => i).filter((i) => stepDates[i] >= sevenDaysAgo && stepDates[i] <= today);
const recentTotal = recentIdx.length;
const recentCompleted = steps.filter((s, i) => {
  const cd = completedDates[i];
  return cd && cd >= sevenDaysAgo && cd <= today;
}).length;
const recentCompletionRate = recentTotal > 0
  ? recentCompleted / recentTotal
  : (recentCompleted > 0 ? 1 : completionRate);

const fourteenDaysAgo = new Date(today); fourteenDaysAgo.setDate(today.getDate() - 14);
const last14Idx = steps.map((_, i) => i).filter((i) => stepDates[i] >= fourteenDaysAgo && stepDates[i] <= today);
const last14Total = last14Idx.length;
const last14Completed = steps.filter((s, i) => {
  const cd = completedDates[i];
  return cd && cd >= fourteenDaysAgo && cd <= today;
}).length;
const consistencyScore = last14Total > 0
  ? last14Completed / last14Total
  : (last14Completed > 0 ? 1 : (elapsedRatio > 0 ? 0.15 : 0.5));

  const remainingSteps = Math.max(0, totalSteps - completedStepCount);
  const timePressure = Math.min(4, Math.max(0, remainingSteps / Math.max(daysRemaining, 1)));

  const difficultyNorm = plan.certificateId
    ? await getDifficultyNorm(plan.certificateId)
    : 0.5;

  const wrongSnap = await db.collection('users').doc(uid)
    .collection('wrong_answers')
    .where('certificationName', '==', certificateName)
    .limit(100)
    .get();
  const subjectWeakRatio = Math.min(0.6, wrongSnap.size / 50 * 0.6);

  const isColdStartUrgent = completedStepCount === 0 && daysRemaining <= 7;

  return {
    features: [
      progressGap, recentCompletionRate, consistencyScore, timePressure,
      difficultyNorm, daysRemainingNorm, elapsedRatio, subjectWeakRatio,
    ],
    isColdStartUrgent,
    debug: {
      totalSteps, elapsedSteps, completedStepCount, recentTotal, last14Total,
      totalCalendarDays, elapsedCalendarDays, daysRemaining,
    },
  };
}
exports.computeFeatures = computeFeatures;

exports.analyzePassRisk = onCall(
  { secrets: [QNET_SERVICE_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
    }
    const certificateName = (request.data?.certificateName || '').trim();
    if (!certificateName) {
      throw new HttpsError('invalid-argument', 'certificateName이 필요합니다.');
    }

    const { features: rawFeatures, isColdStartUrgent, debug } = await computeFeatures(request.auth.uid, certificateName);

    const m = await loadModel();
    const input = tf.tensor2d([normalize(rawFeatures)]);

    const outputs = m.predict(input);
    const outputArr = Array.isArray(outputs) ? outputs : [outputs];
    let riskTensor, passTensor;
    for (const t of outputArr) {
      if (t.shape[t.shape.length - 1] === 3) riskTensor = t;
      else passTensor = t;
    }
    if (!riskTensor || !passTensor) {
      throw new HttpsError('internal', '모델 출력 형태가 예상과 다릅니다.');
    }

    const riskProbs = Array.from(await riskTensor.data());
    const passProb = (await passTensor.data())[0];
    input.dispose();
    outputArr.forEach((t) => t.dispose());

    const riskNames = ['LOW', 'MEDIUM', 'HIGH'];
    let riskIdx = 0;
    for (let i = 1; i < riskProbs.length; i++) {
      if (riskProbs[i] > riskProbs[riskIdx]) riskIdx = i;
    }

    const factors = {
      progressGap: rawFeatures[0],
      recentCompletionRate: rawFeatures[1],
      consistencyScore: rawFeatures[2],
      timePressure: rawFeatures[3],
      difficultyNorm: rawFeatures[4],
      daysRemainingNorm: rawFeatures[5],
      elapsedRatio: rawFeatures[6],
      subjectWeakRatio: rawFeatures[7],
    };
    if (isColdStartUrgent) {
      factors.consistencyScore = 0;
      factors.daysRemainingNorm = Math.min(factors.daysRemainingNorm, 0.15);
    }

    const ruleBasedProb = Math.min(
      0.95,
      Math.max(
        0.05,
        0.55 +
          (factors.recentCompletionRate - 0.5) * 0.35 +
          (factors.consistencyScore - 0.5) * 0.25 -
          factors.progressGap * 0.4 -
          factors.difficultyNorm * 0.15 -
          factors.subjectWeakRatio * 0.2 -
          Math.max(0, 0.3 - factors.daysRemainingNorm) * 0.5
      )
    );

    let finalPassProb = passProb * 0.6 + ruleBasedProb * 0.4;
    let finalRiskIdx = riskIdx;
    if (isColdStartUrgent) {
      finalPassProb = Math.min(finalPassProb, 0.35);
      finalRiskIdx = 2;
    }

    const analysisDocId = certificateName.replace(/\//g, '_');
   await db.collection('users').doc(request.auth.uid)
     .collection('analysis').doc(analysisDocId)
     .set({
       passProbability: Math.round(finalPassProb * 100),
       riskLevel: riskNames[finalRiskIdx],
       certificateName,
       factors,
       debug,
       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
     });
    return {
      success: true,
      passProbability: Math.round(finalPassProb * 100),
      riskLevel: riskNames[finalRiskIdx],
      certificateName,
    };
  }
);

exports.reportExamResult = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  }
  const uid = request.auth.uid;
  const studyPlanId = request.data?.studyPlanId;
  const passed = request.data?.passed;

  if (!studyPlanId || typeof passed !== 'boolean') {
    throw new HttpsError('invalid-argument', 'studyPlanId와 passed(boolean)가 필요합니다.');
  }

  const planRef = db.collection('users').doc(uid).collection('studyPlans').doc(studyPlanId);
  const planSnap = await planRef.get();
  if (!planSnap.exists) {
    throw new HttpsError('not-found', '학습 플랜을 찾을 수 없습니다.');
  }
  const plan = planSnap.data();
  const certificateName = plan.certificateName;
  if (!certificateName) {
    throw new HttpsError('failed-precondition', '학습 플랜에 자격증 정보가 없습니다.');
  }

  const existing = await db.collection('users').doc(uid)
    .collection('examResults')
    .where('studyPlanId', '==', studyPlanId)
    .limit(1)
    .get();
  if (!existing.empty) {
    return { success: true, alreadyReported: true };
  }

  let features;
  try {
    const result = await computeFeatures(uid, certificateName);
    features = result.features;
  } catch (e) {
    console.error('결과 신고 시 feature 계산 실패: ' + e.message);
    throw new HttpsError('internal', '학습 데이터를 분석하지 못했습니다.');
  }

  await db.collection('users').doc(uid).collection('examResults').add({
    studyPlanId,
    certificateId: plan.certificateId || null,
    certificateName,
    examType: plan.examType || 'INTEGRATED',
    examDate: plan.examStartAt || null,
    passed,
    reportedAt: admin.firestore.FieldValue.serverTimestamp(),
    features: {
      progressGap: features[0],
      recentCompletionRate: features[1],
      consistencyScore: features[2],
      timePressure: features[3],
      difficultyNorm: features[4],
      daysRemainingNorm: features[5],
      elapsedRatio: features[6],
      subjectWeakRatio: features[7],
    },
  });

  return { success: true, alreadyReported: false };
});

exports.flagPendingExamResults = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'Asia/Seoul' },
  async (event) => {
    const now = admin.firestore.Timestamp.now();
    const threeDaysAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 3 * 24 * 60 * 60 * 1000
    );

    const plansSnap = await db.collectionGroup('studyPlans')
      .where('examStartAt', '<=', threeDaysAgo)
      .where('resultReportPending', '!=', false)
      .limit(200)
      .get();

    const batch = db.batch();
    let count = 0;

    for (const doc of plansSnap.docs) {
      const uid = doc.ref.parent.parent.id;
      const resultSnap = await db.collection('users').doc(uid)
        .collection('examResults')
        .where('studyPlanId', '==', doc.id)
        .limit(1)
        .get();

      if (resultSnap.empty) {
        batch.update(doc.ref, { resultReportPending: true });
        count++;
      } else {
        batch.update(doc.ref, { resultReportPending: false });
      }
    }

    if (count > 0) await batch.commit();
    console.log(`시험 결과 신고 대기 플랜 ${count}건 플래그 설정`);
  }
);