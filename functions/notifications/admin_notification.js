"use strict";

const admin = require("firebase-admin");
const {
  onCall,
  HttpsError,
} = require("firebase-functions/v2/https");

const {
  sendPush,
} = require("./notification_common");

const db = admin.firestore();

function text(value) {
  return String(value || "").trim();
}

function uniqueStrings(values) {
  if (!Array.isArray(values)) {
    return [];
  }

  return [
    ...new Set(
        values
            .map((value) => text(value))
            .filter((value) => value.length > 0),
    ),
  ];
}

function splitIntoChunks(values, size) {
  const chunks = [];

  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }

  return chunks;
}

async function requireAdministrator(uid) {
  if (!uid) {
    throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
    );
  }

  const snapshot = await db
      .collection("users")
      .doc(uid)
      .get();

  if (!snapshot.exists) {
    throw new HttpsError(
        "permission-denied",
        "사용자 정보를 확인할 수 없습니다.",
    );
  }

  const role = text(snapshot.data()?.role).toUpperCase();

  if (role !== "ADMIN") {
    throw new HttpsError(
        "permission-denied",
        "관리자만 알림을 발송할 수 있습니다.",
    );
  }
}

async function isPushEnabled(uid) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("settings")
      .doc("app")
      .get();

  if (!snapshot.exists) {
    return true;
  }

  return snapshot.data()?.pushEnabled !== false;
}

async function loadRecipients(targetType, requestedUids) {
  if (targetType === "ALL") {
    const snapshot = await db
        .collection("users")
        .where("role", "==", "USER")
        .get();

    return snapshot.docs.filter((document) => {
      const status = text(
          document.data().status || "ACTIVE",
      ).toUpperCase();

      return status === "ACTIVE";
    });
  }

  if (requestedUids.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "특정 회원 발송은 수신자를 선택해야 합니다.",
    );
  }

  if (requestedUids.length > 500) {
    throw new HttpsError(
        "invalid-argument",
        "특정 회원은 한 번에 최대 500명까지 선택할 수 있습니다.",
    );
  }

  const references = requestedUids.map((uid) => {
    return db.collection("users").doc(uid);
  });

  const snapshots = await db.getAll(...references);

  return snapshots.filter((snapshot) => {
    if (!snapshot.exists) {
      return false;
    }

    const data = snapshot.data() || {};
    const role = text(data.role).toUpperCase();
    const status = text(data.status || "ACTIVE").toUpperCase();

    return role === "USER" && status === "ACTIVE";
  });
}

const sendAdminNotification = onCall(
    {
      region: "asia-northeast3",
      timeoutSeconds: 540,
      memory: "512MiB",
      invoker: "public",
    },
    async (request) => {
      await requireAdministrator(request.auth?.uid);

      const title = text(request.data?.title);
      const body = text(request.data?.body);
      const targetType =
        text(request.data?.targetType || "ALL").toUpperCase();
      const targetUids = uniqueStrings(request.data?.targetUids);

      if (!title) {
        throw new HttpsError(
            "invalid-argument",
            "알림 제목을 입력해 주세요.",
        );
      }

      if (title.length > 100) {
        throw new HttpsError(
            "invalid-argument",
            "알림 제목은 100자 이하로 입력해 주세요.",
        );
      }

      if (!body) {
        throw new HttpsError(
            "invalid-argument",
            "알림 내용을 입력해 주세요.",
        );
      }

      if (body.length > 1000) {
        throw new HttpsError(
            "invalid-argument",
            "알림 내용은 1,000자 이하로 입력해 주세요.",
        );
      }

      if (
        targetType !== "ALL" &&
        targetType !== "SPECIFIC_USERS"
      ) {
        throw new HttpsError(
            "invalid-argument",
            "올바르지 않은 발송 대상입니다.",
        );
      }

      const recipients = await loadRecipients(
          targetType,
          targetUids,
      );

      if (recipients.length === 0) {
        throw new HttpsError(
            "not-found",
            "발송 가능한 회원이 없습니다.",
        );
      }

      const dispatchId = db
          .collection("adminNotificationDispatches")
          .doc()
          .id;

      let storedCount = 0;
      let pushSuccessCount = 0;
      let pushFailureCount = 0;
      let pushSkippedCount = 0;

      const chunks = splitIntoChunks(recipients, 20);

      for (const chunk of chunks) {
        const results = await Promise.all(
            chunk.map(async (userDocument) => {
              const uid = userDocument.id;

              const notificationReference = db
                  .collection("users")
                  .doc(uid)
                  .collection("notifications")
                  .doc(dispatchId);

              await notificationReference.set({
                notificationId: dispatchId,
                category: "ADMIN",
                type: "ADMIN_BROADCAST",
                title,
                body,
                refType: "ADMIN_NOTIFICATION",
                createdAt:
                  admin.firestore.FieldValue.serverTimestamp(),
                expiresAt:
                  admin.firestore.Timestamp.fromMillis(
                      Date.now() +
                      30 * 24 * 60 * 60 * 1000,
                  ),
                sentBy: request.auth.uid,
              });

              let successCount = 0;
              let failureCount = 0;
              let skipped = false;

              if (!await isPushEnabled(uid)) {
                skipped = true;

                return {
                  successCount,
                  failureCount,
                  skipped,
                };
              }

              try {
                const result = await sendPush(uid, {
                  title,
                  body,
                  data: {
                    category: "ADMIN",
                    type: "ADMIN_BROADCAST",
                    refType: "ADMIN_NOTIFICATION",
                    notificationId: dispatchId,
                  },
                });

                successCount = result.successCount || 0;
                failureCount = result.failureCount || 0;
              } catch (error) {
                console.error(
                    `[관리자 알림 FCM 실패] uid=${uid}`,
                    error,
                );

                failureCount = 1;
              }

              return {
                successCount,
                failureCount,
                skipped,
              };
            }),
        );

        storedCount += results.length;

        for (const result of results) {
          pushSuccessCount += result.successCount;
          pushFailureCount += result.failureCount;

          if (result.skipped) {
            pushSkippedCount += 1;
          }
        }
      }

      console.log(
          `[관리자 알림 완료] dispatchId=${dispatchId}, ` +
          `recipients=${recipients.length}, ` +
          `stored=${storedCount}, ` +
          `pushSuccess=${pushSuccessCount}, ` +
          `pushFailure=${pushFailureCount}, ` +
          `pushSkipped=${pushSkippedCount}`,
      );

      return {
        dispatchId,
        recipientCount: recipients.length,
        storedCount,
        pushSuccessCount,
        pushFailureCount,
        pushSkippedCount,
      };
    },
);

module.exports = {
  sendAdminNotification,
};