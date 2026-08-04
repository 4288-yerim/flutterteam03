const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const { GoogleGenAI } = require("@google/genai");

const db = admin.firestore();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.generateQuestion = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const { certificationName, examType, subject, generationType } = request.data || {};

    if (!certificationName || !examType) {
      throw new HttpsError("invalid-argument", "필수 정보가 누락되었습니다.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const subjectText = subject ? `"${subject}" 과목의 ` : "";
    const prompt = `너는 "${certificationName}" 자격증 ${examType} 시험 문제를 출제하는 전문가야.
    ${subjectText}실제 시험 난이도와 형식에 맞는 문제 1개를 만들어줘.

    아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "question": "문제 내용",
      "options": ["보기1", "보기2", "보기3", "보기4"],
      "answer": "정답 (options 중 하나와 정확히 일치)",
      "explanation": "정답에 대한 해설"
    }

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 단답형/서술형에 가까운 실기 문제면 options는 빈 배열로 하고 answer에 정답을 직접 써.
    - 한국어로 작성해.`;

    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      const text = result.text;
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      return {
        success: true,
        question: {
          question: parsed.question || "",
          options: parsed.options || [],
          answer: parsed.answer || "",
          explanation: parsed.explanation || "",
        },
      };
    } catch (e) {
      console.error("문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.extractDocumentText = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const { documentUrl } = request.data || {};

    if (!documentUrl) {
      throw new HttpsError("invalid-argument", "문서 URL이 없습니다.");
    }

    try {
      const fileResponse = await axios.get(documentUrl, {
        responseType: "arraybuffer",
      });
      const base64Pdf = Buffer.from(fileResponse.data).toString("base64");

      const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

      const prompt = `첨부된 문서의 내용을 문제 출제에 쓸 수 있도록 핵심 개념, 용어, 수치, 정의를 빠짐없이 정리해줘.
      원문의 문장을 요약하지 말고, 출제 가능한 세부 정보를 최대한 많이 남겨줘.
      다른 설명 없이 정리된 텍스트만 출력해.`;

      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: [
          { inlineData: { mimeType: "application/pdf", data: base64Pdf } },
          { text: prompt },
        ],
      });

      const extractedText = result.text;

      if (!extractedText || extractedText.trim().length < 30) {
        return { success: false, message: "문서에서 내용을 추출하지 못했어요." };
      }

      return { success: true, extractedText };
    } catch (e) {
      console.error("문서 텍스트 추출 실패: " + (e.response?.data ? JSON.stringify(e.response.data) : e.message));
      return { success: false, message: "문서를 분석하지 못했어요." };
    }
  }
);

exports.generateQuestionsFromText = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    const { extractedText, count } = request.data || {};
    const questionCount = count || 20;

    if (!extractedText) {
      throw new HttpsError("invalid-argument", "추출된 텍스트가 없습니다.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `아래는 학습 자료에서 정리한 내용이야:
    ---
    ${extractedText}
    ---

    이 내용을 바탕으로 서로 겹치지 않는 문제 ${questionCount}개를 만들어줘.
    자료에 실제로 나온 개념·용어·수치를 기반으로 다양한 부분에서 골고루 출제해야 해.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 자료 내용만으로 답할 수 있는 문제여야 해.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${questionCount}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("문서 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.generateQuestionsFromWrongAnswers = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = request.auth.uid;
    const count = request.data?.count || 20;
    const certificationName = request.data?.certificationName || null;

    let wrongAnswersRef = db
      .collection("users")
      .doc(uid)
      .collection("wrong_answers");

    if (certificationName) {
      wrongAnswersRef = wrongAnswersRef.where("certificationName", "==", certificationName);
    }

    const snap = await wrongAnswersRef
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    const docs = snap.docs.map((d) => d.data());

    if (docs.length === 0) {
      return { success: false, message: "아직 오답 기록이 없어요. 먼저 문제를 풀어주세요." };
    }

    const summary = docs
      .slice(0, 30)
      .map((d, i) =>
        `${i + 1}. 문제: ${d.question}\n   정답: ${d.correctAnswer}\n   내가 고른 답: ${d.userAnswer}\n   해설: ${d.explanation || ""}`
      )
      .join("\n\n");

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `아래는 학습자가 과거에 틀렸던 문제들이야:
    ---
    ${summary}
    ---

    이 문제들이 다루는 개념과 비슷하지만, 완전히 새로운 문제 ${count}개를 만들어줘.
    같은 개념을 다른 방식으로 물어보거나, 학습자가 헷갈려했던 지점을 다시 확인할 수 있는 문제로 구성해.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${count}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("오답 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.generateQuestionsForCertification = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    const { certificationName, examType, subject, count } = request.data || {};
    const questionCount = count || 20;

    if (!certificationName || !examType) {
      throw new HttpsError("invalid-argument", "필수 정보가 누락되었습니다.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const subjectText = subject ? `"${subject}" 과목의 ` : "";
    const prompt = `너는 "${certificationName}" 자격증 ${examType} 시험 문제를 출제하는 전문가야.
    ${subjectText}실제 시험 난이도와 형식에 맞는, 서로 겹치지 않는 문제 ${questionCount}개를 만들어줘.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 단답형/서술형에 가까운 실기 문제면 options는 빈 배열로 하고 answer에 정답을 직접 써.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${questionCount}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("자격증 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);