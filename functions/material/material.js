const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const axios = require("axios");
const { GoogleGenAI } = require("@google/genai");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.summarizeMaterial = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180, memory: "512MiB" },
  async (request) => {
    const fileUrls = request.data?.fileUrls;
    const selectedCertificate = (request.data?.selectedCertificate || "").trim();
    const forceSummary = !!request.data?.forceSummary;

    if (!Array.isArray(fileUrls) || fileUrls.length === 0) {
      throw new HttpsError("invalid-argument", "요약할 파일 URL이 없습니다.");
    }
    if (!selectedCertificate) {
      throw new HttpsError("invalid-argument", "선택한 자격증 정보가 없습니다.");
    }
    if (fileUrls.length > 10) {
      throw new HttpsError("invalid-argument", "한 번에 요약할 수 있는 파일 개수를 초과했습니다.");
    }

    let fileParts;
    try {
      fileParts = await Promise.all(
        fileUrls.map(async (url) => {
          const res = await axios.get(url, { responseType: "arraybuffer" });
          const mimeType = res.headers["content-type"] || "application/pdf";
          const base64 = Buffer.from(res.data).toString("base64");
          return { inlineData: { mimeType, data: base64 } };
        })
      );
    } catch (e) {
      console.error("요약용 파일 다운로드 실패: " + e.message);
      throw new HttpsError("internal", "업로드한 파일을 불러오지 못했습니다.");
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const matchInstruction = forceSummary
      ? `certificate_match는 항상 true로 응답해. (사용자가 이미 자료를 확인했고 계속 진행하기로 선택했음)`
      : `가장 먼저, 첨부된 자료의 실제 내용이 "${selectedCertificate}" 자격증과 실질적으로 관련이 있는지 판단해.
      - 관련이 있으면 certificate_match를 true로, detected_certificate는 "${selectedCertificate}"와 동일하게, mismatch_reason은 빈 문자열로 응답해.
      - 관련이 없어 보이면 certificate_match를 false로, detected_certificate에는 자료가 실제로 어떤 자격증/분야에 가까운지 적고,
        mismatch_reason에는 왜 그렇게 판단했는지 1~2문장으로 간단히 적어.`;

    const prompt = `너는 자격증 시험 준비를 돕는 학습 자료 요약 도우미야.
사용자가 선택한 자격증은 "${selectedCertificate}"이고, 총 ${fileParts.length}개의 자료 파일이 첨부되어 있어.

수행할 작업:
1. ${matchInstruction}
2. 자료의 핵심 개념, 중요 용어, 정의, 수치를 놓치지 않고 시험 대비에 도움이 되도록 구조적으로 요약해.
   - 소제목과 목록(줄바꿈)을 활용해서 읽기 쉽게 정리해.
   - 자료에 없는 내용을 지어내지 마.

아래 JSON 형식으로만 응답하고, 다른 텍스트나 코드블록 표시(\`\`\`)는 절대 포함하지 마:
{
  "certificate_match": true 또는 false,
  "detected_certificate": "자료가 실제로 관련있어 보이는 자격증/분야 이름",
  "mismatch_reason": "불일치 판단 이유 (일치하면 빈 문자열)",
  "summary": "정리된 요약 내용 전체 (문자열)",
  "original_length": 자료 원문 전체 글자 수 추정치 (숫자)
}`;

    const tryGenerate = async () => {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: [...fileParts, { text: prompt }],
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error("JSON 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    let parsed;
    try {
      parsed = await tryGenerate();
    } catch (firstError) {
      console.error("요약 1차 파싱 실패, 재시도: " + firstError.message);
      try {
        parsed = await tryGenerate();
      } catch (secondError) {
        console.error("요약 생성 실패: " + secondError.message);
        throw new HttpsError("internal", "요약을 생성하지 못했습니다. 다시 시도해주세요.");
      }
    }

    const summary = (parsed.summary || "").trim();

    const certificateMatch = forceSummary ? true : parsed.certificate_match !== false;

    if (certificateMatch && !summary) {
      throw new HttpsError("internal", "서버에서 빈 요약 결과를 반환했습니다.");
    }

    const originalLength = Number.isFinite(Number(parsed.original_length))
      ? Number(parsed.original_length)
      : 0;

    return {
      certificate_match: certificateMatch,
      detected_certificate: parsed.detected_certificate || "",
      mismatch_reason: parsed.mismatch_reason || "",
      summary,
      original_length: originalLength,
      summary_length: summary.length,
      file_count: fileParts.length,
    };
  }
);