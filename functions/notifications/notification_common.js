const admin = require("firebase-admin");

const db = admin.firestore();

async function canSend(uid, categoryField, subTypeField = null) {
  if (!uid || !categoryField) {
    return false;
  }

  const settingsRef = db
      .collection("users")
      .doc(uid)
      .collection("settings")
      .doc("app");

  const settingsSnapshot = await settingsRef.get();

  // 설정 문서가 없는 기존 사용자는 기본 활성화로 처리한다.
  if (!settingsSnapshot.exists) {
    console.log(
        `[알림 설정 기본값 사용] 설정 문서 없음: ${uid}`,
    );
    return true;
  }

  const settings = settingsSnapshot.data() || {};

  // 명시적으로 false인 경우에만 차단한다.
  if (settings.pushEnabled === false) {
    console.log(
        `[알림 건너뜀] pushEnabled=false: ${uid}`,
    );
    return false;
  }

  if (settings[categoryField] === false) {
    console.log(
        `[알림 건너뜀] ${categoryField}=false: ${uid}`,
    );
    return false;
  }

  if (
    subTypeField &&
    settings[subTypeField] === false
  ) {
    console.log(
        `[알림 건너뜀] ${subTypeField}=false: ${uid}`,
    );
    return false;
  }

  return true;
}

async function sendPush(uid, params) {
  if (!uid) {
    throw new Error("uid가 필요합니다.");
  }

  const title = String(params?.title || "").trim();
  const body = String(params?.body || "").trim();

  if (!title || !body) {
    throw new Error("알림 제목과 내용이 필요합니다.");
  }

  const userRef = db.collection("users").doc(uid);
  const userSnapshot = await userRef.get();

  if (!userSnapshot.exists) {
    console.log(`[알림 건너뜀] 사용자 문서 없음: ${uid}`);

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
      removedTokenCount: 0,
    };
  }

  const userData = userSnapshot.data();

  const rawTokens = Array.isArray(userData.fcmTokens) ?
    userData.fcmTokens :
    [];

  const tokens = [
    ...new Set(
        rawTokens
            .filter((token) => typeof token === "string")
            .map((token) => token.trim())
            .filter((token) => token.length > 0),
    ),
  ];

  if (tokens.length === 0) {
    console.log(`[알림 건너뜀] FCM 토큰 없음: ${uid}`);

    return {
      successCount: 0,
      failureCount: 0,
      tokenCount: 0,
      removedTokenCount: 0,
    };
  }

  const messageData = {};

  for (const [key, value] of Object.entries(params.data || {})) {
    if (value === null || value === undefined) {
      continue;
    }

    messageData[key] = String(value);
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title,
      body,
    },
    data: messageData,
    android: {
      priority: "high",
      notification: {
        channelId: "default_notification_channel",
        sound: "default",
      },
    },
  });

  const invalidTokens = [];

  response.responses.forEach((result, index) => {
    if (result.success) {
      return;
    }

    const errorCode = result.error?.code;

    console.error(
        `[FCM 발송 실패] uid=${uid}, code=${errorCode}`,
        result.error,
    );

    if (
      errorCode === "messaging/invalid-registration-token" ||
      errorCode === "messaging/registration-token-not-registered"
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(
          ...invalidTokens,
      ),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(
        `[FCM 토큰 제거] uid=${uid}, count=${invalidTokens.length}`,
    );
  }

  console.log(
      `[FCM 발송 완료] uid=${uid}, ` +
      `success=${response.successCount}, ` +
      `failure=${response.failureCount}`,
  );

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
    tokenCount: tokens.length,
    removedTokenCount: invalidTokens.length,
  };
}

module.exports = {
  canSend,
  sendPush,
};