const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  sendPush,
} = require("./notification_common");

/**
 * 로그인한 사용자가 자기 기기로만 테스트 알림을 보낸다.
 */
const sendTestPush = onCall(
    {},
    async (request) => {
      const uid = request.auth?.uid;

      if (!uid) {
        throw new HttpsError(
            "unauthenticated",
            "로그인한 사용자만 테스트할 수 있습니다.",
        );
      }

      const title = String(
          request.data?.title || "FCM 서버 테스트",
      ).trim();

      const body = String(
          request.data?.body ||
          "Cloud Functions에서 보낸 알림입니다.",
      ).trim();

      if (!title || !body) {
        throw new HttpsError(
            "invalid-argument",
            "알림 제목과 내용을 입력해주세요.",
        );
      }

      if (title.length > 100) {
        throw new HttpsError(
            "invalid-argument",
            "알림 제목은 100자 이하여야 합니다.",
        );
      }

      if (body.length > 500) {
        throw new HttpsError(
            "invalid-argument",
            "알림 내용은 500자 이하여야 합니다.",
        );
      }

      try {
        const result = await sendPush(uid, {
          title,
          body,
          data: {
            refType: "TEST",
            refId: "",
          },
        });

        return {
          success: result.successCount > 0,
          ...result,
        };
      } catch (error) {
        console.error("테스트 푸시 발송 실패:", error);

        throw new HttpsError(
            "internal",
            "테스트 알림 발송에 실패했습니다.",
        );
      }
    },
);

module.exports = {
  sendTestPush,
};