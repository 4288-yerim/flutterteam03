const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const { GoogleGenAI } = require("@google/genai");

const db = admin.firestore();

const QNET_SERVICE_KEY = defineSecret("QNET_SERVICE_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.getCertificateSchedule = onCall(
  { secrets: [QNET_SERVICE_KEY] },
  async (request) => {
    const year = request.data?.year || new Date().getFullYear();
    const cacheDoc = db.collection("certSchedule").doc(`${year}`);

    const cached = await cacheDoc.get();
    if (cached.exists) {
      const cachedAt = cached.data().cachedAt?.toDate();
      if (cachedAt && (Date.now() - cachedAt.getTime()) < 24 * 60 * 60 * 1000) {
        return { success: true, items: cached.data().items };
      }
    }

    try {
      const response = await axios.get(
        "https://apis.data.go.kr/B490007/qualExamSchd/getQualExamSchdList",
        {
          params: {
            serviceKey: QNET_SERVICE_KEY.value(),
            numOfRows: 200,
            pageNo: 1,
            dataFormat: "json",
            implYy: year,
            qualgbCd: "T",
          },
        }
      );

      const items = response.data?.response?.body?.items?.item || [];

      await cacheDoc.set({
        items,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, items };
    } catch (e) {
      console.error("자격시험 일정 조회 실패: " + JSON.stringify(e.response?.data || { message: e.message }));
      return { success: false, message: e.message };
    }
  }
);

exports.suggestCertificatesForJob = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const job = (request.data?.job || "").trim();
    if (!job) {
      throw new HttpsError("invalid-argument", "직무를 입력해주세요.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `"${job}"이(가) 실제 직무/직업명이 아니거나 자격증 추천이 불가능한 값이면 빈 배열 []만 반환해.
    실제 직무라면, 이 직무를 목표로 하는 사람에게 도움이 되는 한국 자격증을 최대 6개까지 추천해줘.
    국가기술자격, 국가전문자격, 국가공인 민간자격을 우선 고려해.

    배열의 순서는 반드시 "실제로 준비하고 취득해야 하는 순서"를 따라야 해:
    - 같은 분야에 등급이 여러 개 있는 국가기술자격은 낮은 등급부터 순서대로 나열해 (기능사 → 산업기사 → 기사 → 기능장 → 기술사).
      예: "정보처리산업기사"는 "정보처리기사"보다 반드시 먼저 나와야 해.
    - 등급 체계가 없는 자격증(어학시험, IT 인증 등)은 난이도나 우선순위가 낮은 것부터 배치해.
    - 서로 다른 분야의 자격증 사이에서는 직무에 더 핵심적이고 활용도가 높은 것을 먼저 배치해.

    아래 JSON 배열 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
    [{"name": "자격증 이름", "description": "한 문장 설명"}]`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      const text = result.text;
      const jsonMatch = text.match(/\[[\s\S]*\]/);
      const certs = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      return { success: true, certificates: certs };
    } catch (e) {
      console.error("자격증 추천 실패: " + e.message);
      return { success: false, message: "추천을 생성하지 못했어요." };
    }
  }
);

exports.incrementJobPopularity = onCall(async (request) => {
  const job = (request.data?.job || "").trim().toLowerCase().replace(/\s+/g, "");
  if (!job || job.length > 30) {
    throw new HttpsError("invalid-argument", "잘못된 직무명입니다.");
  }

  const ref = db.collection("job_popularity").doc(job);
  await ref.set(
    {
      displayName: request.data.job.trim(),
      count: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { success: true };
});

exports.getPopularJobs = onCall(async () => {
  const snap = await db
    .collection("job_popularity")
    .orderBy("count", "desc")
    .limit(5)
    .get();
  return { jobs: snap.docs.map(d => ({ name: d.data().displayName, count: d.data().count })) };
});

exports.validateCertificateName = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) return { valid: false };

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `"${name}"이(가) 실제로 존재하는 자격증, 수료증, 어학/IT 인증시험 이름인지 판단해줘.
국가기술자격, 국가전문자격, 민간자격, 어학시험(TOEIC 등), IT 인증(정보처리기사 등) 모두 포함해서 폭넓게 판단해.
아래 JSON 형식으로만 응답하고 다른 텍스트는 포함하지 마:
{"valid": true} 또는 {"valid": false}`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      const text = result.text;
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);
      return { valid: parsed.valid === true };
    } catch (e) {
      console.error("자격증 검증 실패: " + e.message);
      return { valid: true };
    }
  }
);

exports.getCertificateStructure = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `"${name}"이(가) 실제 존재하는 한국의 자격증/인증시험이 맞는지 먼저 판단해.
    존재하지 않거나 자격증이 아니면 {"valid": false}만 반환해.

    실제 자격증이라면, 이 시험의 구조를 분석해서 아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true,
      "hasWritten": true 또는 false,
      "hasPractical": true 또는 false,
      "isIntegrated": true 또는 false,
      "writtenSubjects": ["과목1", "과목2"],
      "practicalSubjects": ["과목1"],
      "integratedSubjects": []
    }

    규칙:
    - 필기/실기 구분이 있는 시험은 isIntegrated를 false로 하고, hasWritten/hasPractical과 writtenSubjects/practicalSubjects를 채워.
    - 필기/실기 구분 없이 하나로 치러지는 시험(어학시험, 한국사능력검정시험 등)은 isIntegrated를 true로 하고 integratedSubjects만 채우고 hasWritten/hasPractical은 false로 해.
    - 과목이 명확히 나뉘지 않는 시험은 해당 배열에 전체 시험명을 하나의 항목으로 넣어.`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      const text = result.text;
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      if (parsed.valid !== true) {
        return { success: false, message: "실제 존재하는 자격증을 찾지 못했어요." };
      }

      return {
        success: true,
        structure: {
          name,
          hasWritten: !!parsed.hasWritten,
          hasPractical: !!parsed.hasPractical,
          isIntegrated: !!parsed.isIntegrated,
          writtenSubjects: parsed.writtenSubjects || [],
          practicalSubjects: parsed.practicalSubjects || [],
          integratedSubjects: parsed.integratedSubjects || [],
        },
      };
    } catch (e) {
      console.error("자격증 구조 분석 실패: " + e.message);
      return { success: false, message: "자격증 정보를 불러오지 못했어요." };
    }
  }
);

exports.estimateCertificateInfo = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `오늘 날짜는 ${todayStr}이야.
    "${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 판단하고,
    이 시험의 "오늘 이후로 가장 가까운 다가오는 회차"의 접수 기간과 시험일을 추정해줘.

    아래 JSON 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true 또는 false,
      "level": "국가기술자격/국가전문자격/민간자격/어학시험 등 자격 구분 (모르면 null)",
      "registrationPeriod": "YYYY. MM. DD ~ YYYY. MM. DD 형식의 가장 가까운 다가오는 접수 기간 (모르면 null)",
      "examDate": "YYYY. MM. DD 형식의 가장 가까운 다가오는 시험일 (모르면 null)"
    }

   규칙:
       - valid가 false면 나머지 필드는 모두 null로 해.
       - registrationPeriod의 종료일(접수 마감일)은 반드시 오늘(${todayStr}) 이후여야 해. 접수가 이미 마감된 회차는 절대 반환하지 마.
       - examDate는 registrationPeriod 다음 회차의 시험일이면 되고, 오늘 이후인지는 별도로 신경 쓰지 않아도 돼 (접수기간만 안 지나면 됨).
       - 정확한 공식 일정을 모르더라도, 이 자격증의 일반적인 연간 시행 회차 패턴(예: 정보처리기사는 보통 1월/4월/7월경 접수, 5~6월/8월/10~11월경 시험 등)을 근거로 오늘 기준 다음 회차를 계산해서 구체적인 날짜로 답해.
       - "보통 연 O회 시행" 같은 설명 문장이 아니라, 반드시 위 예시처럼 실제 날짜 형식으로 답해.
       - 그래도 도저히 패턴을 알 수 없는 자격증이면 null로 응답해 (이 경우 앱에서 "주관사 확인 필요" 안내를 대신 보여줌).`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      if (parsed.valid !== true) {
        return { success: false, message: "자격증 정보를 추정하지 못했어요." };
      }

      return {
        success: true,
        info: {
          level: parsed.level || null,
          registrationPeriod: parsed.registrationPeriod || null,
          examDate: parsed.examDate || null,
        },
      };
    } catch (e) {
      console.error("자격증 정보 추정 실패: " + e.message);
      return { success: false, message: "자격증 정보를 추정하지 못했어요." };
    }
  }
);

exports.estimateCertificateDetailInfo = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `"${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 판단하고,
     이 시험의 응시료, 출제 경향, 취득 방법 정보를 알려줘.

     아래 JSON 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
     {
       "valid": true 또는 false,
       "examFee": {
         "firstLabel": "1차 또는 필기 등 (없으면 null)",
         "firstAmount": 숫자 (원 단위, 모르면 null),
         "secondLabel": "2차 또는 실기 등 (없으면 null)",
         "secondAmount": 숫자 (원 단위, 모르면 null)
       },
       "examTrends": {
         "header": "예: 실기시험 출제 경향 (없으면 null)",
         "topics": ["세부 출제 항목1", "세부 출제 항목2"]
       },
       "howToObtain": {
         "agency": "시행처 (모르면 null)",
         "department": "관련 학과 (없으면 null)",
         "writtenSubjects": ["필기 과목1", "필기 과목2"],
         "practicalSubjects": "실기 과목/방식 설명 (없으면 null)",
         "passCriteria": "합격 기준 (모르면 null)"
       }
     }

     규칙:
     - valid가 false면 다른 필드는 모두 null 또는 빈 값으로 해.
     - 필기/실기 구분이 없는 시험(어학시험 등)은 writtenSubjects에 전체 과목/영역을 넣고 practicalSubjects는 null로 해.
     - examTrends.topics는 가능하면 2개 이상 항목으로 나눠서 구성해.
     - 모르는 항목은 추측해서 지어내지 말고 null 또는 빈 배열로 응답해.`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      if (parsed.valid !== true) {
        return { success: false, message: "자격증 상세정보를 추정하지 못했어요." };
      }

      return { success: true, detail: parsed };
    } catch (e) {
      console.error("자격증 상세정보 추정 실패: " + e.message);
      return { success: false, message: "자격증 상세정보를 추정하지 못했어요." };
    }
  }
);

function slugifyForId(name) {
  return name
    .normalize("NFKD")
    .replace(/[^\w가-힣]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 20);
}

exports.addCertificationFromAi = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const existing = await db.collection("certifications")
      .where("jmfldnm", "==", name)
      .limit(1)
      .get();
    if (!existing.empty) {
      return { success: true, alreadyExists: true, certificate: existing.docs[0].data() };
    }

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `오늘 날짜는 ${todayStr}이야.
    "${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 웹 검색을 통해 확인하고 판단해줘.
    실제 존재하지 않으면 반드시 valid를 false로 응답해. 절대 지어내지 마.

    자격증이 실제 존재한다면 valid는 true로 해.
    nextRound(다음 시험 일정)는 절대 비워두지 마. 공식 일정을 100% 확신하지 못하더라도,
    이 자격증의 일반적인 연간 시행 횟수와 패턴(예: 보통 짝수달 접수, 연 4회 시행 등)을 근거로
    오늘 이후 가장 가까운 회차를 반드시 구체적인 날짜로 추정해서 채워.
    "모른다"는 이유로 docregstartat/docregendat/docexamstartat을 null로 두는 것은 허용하지 않아.
    다만 필기/실기 구분이 아예 없는 시험의 실기 관련 필드(pracexamstartat 등)는 null이 맞아.

    아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true 또는 false,
      "classification": {
        "qualgbcd": "T(국가기술자격)/S(국가전문자격)/P(민간자격)/L(어학/기타)",
        "qualgbnm": "국가기술자격/국가전문자격/민간자격/어학시험 등",
        "seriescd": "등급 코드 (예: 01=기술사,02=기사,03=산업기사,04=기능사, 없으면 null)",
        "seriesnm": "기술사/기사/산업기사/기능사/1급/2급 등 (없으면 null)",
        "obligfldcd": "대분류 코드 (모르면 null)",
        "obligfldnm": "대분류명 (예: 정보통신, 기계, 어학 등)",
        "mdobligfldcd": "중분류 코드 (모르면 null)",
        "mdobligfldnm": "중분류명 (예: 정보기술, 기계장비설비.설치 등)"
      },
      "examFee": {
        "feeRound1": 숫자 (1차/필기 응시료 원 단위, 모르면 null),
        "feeRound2": 숫자 (2차/실기 응시료 원 단위, 없거나 모르면 null)
      },
      "howToObtain": "시행처, 관련학과, 시험과목, 합격기준 등을 담은 취득방법 설명 (문장)",
      "nextRound": {
        "implplannm": "예: 2026년 정기 기사 3회 (확신 없으면 null)",
        "year": 2026,
        "docregstartat": "YYYY-MM-DD (필기/1차 접수 시작일, 확신 없으면 null)",
        "docregendat": "YYYY-MM-DD (필기/1차 접수 마감일, 반드시 오늘 이후, 확신 없으면 null)",
        "docexamstartat": "YYYY-MM-DD (필기/1차 시험일, 확신 없으면 null)",
        "docexamendat": "YYYY-MM-DD (필기/1차 시험 종료일, 당일이면 시작일과 동일)",
        "docpassat": "YYYY-MM-DD (필기 합격자 발표일, 없으면 null)",
        "docsubmitstartat": "YYYY-MM-DD (실기 접수 시작일, 없으면 null)",
        "docsubmitendat": "YYYY-MM-DD (실기 접수 마감일, 없으면 null)",
        "pracexamstartat": "YYYY-MM-DD (실기 시험 시작일, 없으면 null)",
        "pracexamendat": "YYYY-MM-DD (실기 시험 종료일, 없으면 null)",
        "pracpassstartat": "YYYY-MM-DD (최종 발표 관련일, 없으면 null)",
        "pracpassendat": "YYYY-MM-DD (최종 합격자 발표일, 없으면 null)"
      }
    }

    규칙:
    - "오늘 이후로 가장 가까운 다가오는 회차" 기준으로 nextRound를 채워.
    - docregendat(접수마감)은 반드시 오늘(${todayStr}) 이후여야 해. 확신이 없으면 null로 둬.
    - 필기/실기 구분이 없는 시험은 실기 관련 필드는 모두 null로 해.
    - 날짜는 반드시 YYYY-MM-DD 형식으로만 응답해.
    - classification, examFee, howToObtain은 자격증이 실존하면 최대한 채워줘 (이 값들이 없다고 valid를 false로 하지는 마).`;

    let parsed;
    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);
    } catch (e) {
      console.error("자격증 추가 AI 분석 실패: " + e.message);
      return { success: false, message: "자격증 정보를 확인하지 못했어요." };
    }

    if (parsed.valid !== true) {
      return { success: false, message: "실제 존재가 확인되지 않는 자격증이에요." };
    }

    const cls = parsed.classification || {};
    const fee = parsed.examFee || {};
    const round = parsed.nextRound || {};
    const howToObtain = (parsed.howToObtain || "").trim();

    if (!howToObtain || (fee.feeRound1 == null && fee.feeRound2 == null)) {
      return { success: false, message: "자격증 정보가 충분히 확인되지 않아 추가하지 못했어요." };
    }

    const toTimestamp = (dateStr) => {
      if (!dateStr) return null;
      const d = new Date(`${dateStr}T00:00:00+09:00`);
      if (isNaN(d.getTime())) return null;
      return admin.firestore.Timestamp.fromDate(d);
    };

    const hasValidSchedule =
      !!round.docregstartat && !!round.docregendat && !!round.docexamstartat;

    let docregendatTs = null;
    if (hasValidSchedule) {
      docregendatTs = toTimestamp(round.docregendat);
      if (!docregendatTs || docregendatTs.toMillis() <= Date.now()) {
        docregendatTs = null;
      }
    }
    const scheduleUsable = hasValidSchedule && !!docregendatTs;

    const jmcd = `AI${slugifyForId(name).toUpperCase()}`;
    const baseFields = {
      jmcd,
      jmfldnm: name,
      qualgbcd: cls.qualgbcd || null,
      qualgbnm: cls.qualgbnm || null,
      seriescd: cls.seriescd || null,
      seriesnm: cls.seriesnm || null,
      obligfldcd: cls.obligfldcd || null,
      obligfldnm: cls.obligfldnm || null,
      mdobligfldcd: cls.mdobligfldcd || null,
      mdobligfldnm: cls.mdobligfldnm || null,
    };

    const feeParts = [];
    if (fee.feeRound1 != null) feeParts.push(`1차: ${fee.feeRound1}`);
    if (fee.feeRound2 != null) feeParts.push(`2차: ${fee.feeRound2}`);

    const certRef = db.collection("certifications").doc(jmcd);
    const nowTs = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    batch.set(certRef, {
      ...baseFields,
      source: "AI",
      scheduleConfirmed: scheduleUsable,
      updatedAt: nowTs,
    });

    batch.set(certRef.collection("details").doc("examFee"), {
      ...baseFields,
      infogb: "응시수수료",
      contents: feeParts.join(", "),
      feeRound1: fee.feeRound1 ?? null,
      feeRound2: fee.feeRound2 ?? null,
      updatedat: nowTs,
    });

    batch.set(certRef.collection("details").doc("howToObtain"), {
      ...baseFields,
      infogb: "취득방법",
      contents: howToObtain,
      updatedat: nowTs,
    });

    if (scheduleUsable) {
      const scheduleId = `${jmcd}_${(round.docregstartat || "").replace(/-/g, "")}`;
      batch.set(certRef.collection("schedules").doc(scheduleId), {
        ...baseFields,
        implplannm: round.implplannm || null,
        year: round.year || today.getFullYear(),
        docregstartat: toTimestamp(round.docregstartat),
        docregendat: docregendatTs,
        docexamstartat: toTimestamp(round.docexamstartat),
        docexamendat: toTimestamp(round.docexamendat || round.docexamstartat),
        docpassat: toTimestamp(round.docpassat),
        docsubmitstartat: toTimestamp(round.docsubmitstartat),
        docsubmitendat: toTimestamp(round.docsubmitendat),
        pracregstartat: toTimestamp(round.docsubmitstartat),
        pracregendat: toTimestamp(round.docsubmitendat),
        pracexamstartat: toTimestamp(round.pracexamstartat),
        pracexamendat: toTimestamp(round.pracexamendat),
        pracpassstartat: toTimestamp(round.pracpassstartat),
        pracpassendat: toTimestamp(round.pracpassendat),
        sortdate: toTimestamp(round.docregstartat),
        updatedat: nowTs,
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      console.error("자격증 추가 저장 실패: " + e.message);
      return { success: false, message: "자격증 정보를 저장하지 못했어요." };
    }

    const savedSnap = await certRef.get();
    return {
      success: true,
      alreadyExists: false,
      scheduleConfirmed: scheduleUsable,
      certificate: savedSnap.data(),
    };
  }
);

async function buildInitialGoalData(goalCertificateId) {
  if (!goalCertificateId) return null;

  const certRef = db.collection("certifications").doc(goalCertificateId);
  const certSnap = await certRef.get();
  if (!certSnap.exists) {
    console.error(`목표 자격증 조회 실패: certifications/${goalCertificateId} 없음`);
    return null;
  }
  const cert = certSnap.data();

  const now = admin.firestore.Timestamp.now();
  let scheduleId = null;
  let schedule = null;

  try {
    let scheduleSnap = await certRef
      .collection("schedules")
      .where("docregendat", ">=", now)
      .orderBy("docregendat", "asc")
      .limit(1)
      .get();

    if (scheduleSnap.empty) {
      scheduleSnap = await certRef
        .collection("schedules")
        .where("pracregendat", ">=", now)
        .orderBy("pracregendat", "asc")
        .limit(1)
        .get();
    }

    if (!scheduleSnap.empty) {
      scheduleId = scheduleSnap.docs[0].id;
      schedule = scheduleSnap.docs[0].data();
    }
  } catch (e) {
    console.error("목표 자격증 일정 조회 실패: " + e.message);
  }

  const qualTypeMap = { T: "TECHNICAL", S: "PROFESSIONAL", P: "PRIVATE", L: "LANGUAGE" };
  const qualificationType = qualTypeMap[cert.qualgbcd] || "TECHNICAL";

  let targetExamType = "INTEGRATED";
  if (schedule?.docexamstartat && schedule?.pracexamstartat) {
    targetExamType = "WRITTEN";
  } else if (schedule?.pracexamstartat) {
    targetExamType = "PRACTICAL";
  }

  return {
    certificateId: cert.jmcd || goalCertificateId,
    certificateName: cert.jmfldnm || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    goalStatus: "ACTIVE",
    isMainGoal: false,
    qualificationType,
    scheduleId,
    targetExamDate: schedule?.docexamstartat || schedule?.pracexamstartat || null,
    targetExamType,
    targetPassAnnouncementDate: schedule?.docpassat || null,
    targetPassAnnouncementEndDate: schedule?.pracpassendat || null,
    targetRegistrationEndDate: schedule?.docregendat || schedule?.pracregendat || null,
    targetRegistrationStartDate: schedule?.docregstartat || schedule?.pracregstartat || null,
    targetRound: schedule?.implplannm || null,
  };
}

async function saveInitialGoal(uid, goalCertificateId) {
  const goalData = await buildInitialGoalData(goalCertificateId);
  if (!goalData) return;

  const goalsRef = db.collection("users").doc(uid).collection("goals");
  const existing = await goalsRef.limit(1).get();
  goalData.isMainGoal = existing.empty;

  await goalsRef.add(goalData);
}
exports.saveInitialGoal = saveInitialGoal;

exports.createInitialGoal = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const goalCertificateId = request.data?.goalCertificateId || null;
  if (!goalCertificateId) {
    return { success: true, skipped: true };
  }

  try {
    await saveInitialGoal(request.auth.uid, goalCertificateId);
    return { success: true };
  } catch (e) {
    console.error("createInitialGoal 실패: " + e.message);
    return { success: false, message: e.message };
  }
});