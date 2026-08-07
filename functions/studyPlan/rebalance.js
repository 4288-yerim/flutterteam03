const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const db = admin.firestore();

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

exports.rebalanceStudyPlan = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  }
  const uid = request.auth.uid;
  const studyPlanId = request.data?.studyPlanId;
  if (!studyPlanId) {
    throw new HttpsError('invalid-argument', 'studyPlanId가 필요합니다.');
  }

  const planRef = db.collection('users').doc(uid).collection('studyPlans').doc(studyPlanId);
  const planSnap = await planRef.get();
  if (!planSnap.exists) {
    throw new HttpsError('not-found', '학습 플랜을 찾을 수 없습니다.');
  }

  const plan = planSnap.data();
  const steps = Array.isArray(plan.steps) ? plan.steps : [];
  if (steps.length === 0) {
    throw new HttpsError('failed-precondition', '학습 플랜에 단계가 없습니다.');
  }

  const recommendedStartDate = plan.recommendedStudyStartDate
    ? new Date(plan.recommendedStudyStartDate + 'T00:00:00')
    : new Date();

  const nowKst = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const today = new Date(nowKst.getUTCFullYear(), nowKst.getUTCMonth(), nowKst.getUTCDate());

  const pendingIdx = steps.map((_, i) => i).filter((i) => !steps[i].isCompleted);
  if (pendingIdx.length === 0) {
    return { success: true, rebalanced: false, message: '재조정할 항목이 없어요.' };
  }

  const examDate = plan.examStartAt ? plan.examStartAt.toDate() : null;
  const daysRemaining = examDate
    ? Math.max(1, Math.round((examDate - today) / (1000 * 60 * 60 * 24)))
    : Math.max(1, pendingIdx.length);

  const perDay = Math.max(1, Math.ceil(pendingIdx.length / daysRemaining));
  const newSteps = [...steps];
  let cursor = 0;
  for (let d = 0; d < daysRemaining && cursor < pendingIdx.length; d++) {
    const date = new Date(today);
    date.setDate(today.getDate() + d);
    const label = `${date.getMonth() + 1}/${date.getDate()}`;
    for (let k = 0; k < perDay && cursor < pendingIdx.length; k++, cursor++) {
      const idx = pendingIdx[cursor];
      newSteps[idx] = { ...newSteps[idx], dayLabel: label };
    }
  }

  await planRef.update({
    steps: newSteps,
    lastRebalancedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, rebalanced: true, redistributedCount: pendingIdx.length };
});