const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenAI } = require("@google/genai");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const SYSTEM_PROMPT = "너는 자격증 학습 앱의 상담 챗봇 '구름iT'이야. " +
  "사용자의 인사, 감사 인사, 짧은 잡담, 혹은 앱 사용법과 관련된 아주 간단한 질문에만 " +
  "친절하고 간결하게(2~3문장 이내) 한국어 존댓말로 답해. " +
  "다음 경우에는 절대 답변을 만들지 말고 정확히 이 문자열만 출력해: __NO_ANSWER__ " +
  "- 앱/서비스와 관련 없는 질문(일반 상식, 시사, 코딩, 개인 신상 등), " +
  "- 욕설/혐오/성적/폭력적인 내용, " +
  "- 의미를 알 수 없는 문장이나 랜덤한 문자열, 스팸성 내용, " +
  "- 의학적/법적/재정적 조언이 필요한 질문, " +
  "- 답변에 확신이 없는 모든 질문. " +
  "절대 마크다운, 이모지 남발, 긴 목록을 쓰지 마.";

exports.chatbotReply = onCall(
  {
    secrets: [GEMINI_API_KEY],
    region: "asia-northeast3",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const userText = (request.data && request.data.message
      ? String(request.data.message)
      : ""
    ).trim();

    if (!userText || userText.length > 300) {
      return { reply: null };
    }

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    let text;
    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: SYSTEM_PROMPT + "\n\n사용자 메시지: \"" + userText + "\"",
      });
      text = (result.text || "").trim();
    } catch (err) {
      console.error("Gemini 챗봇 응답 실패: " + err.message);
      return { reply: null };
    }

    if (!text || text.indexOf("__NO_ANSWER__") !== -1) {
      return { reply: null };
    }

    return { reply: text };
  }
);