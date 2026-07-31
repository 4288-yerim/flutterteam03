"use strict";

const admin = require("firebase-admin");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {sendPush} = require("./notification_common");

const db = admin.firestore();

function text(value, fallback = "") {
  const result = String(value || "").trim();
  return result || fallback;
}

async function isEnabled(uid) {
  if (!uid) return false;
  const snapshot = await db.collection("users").doc(uid)
      .collection("settings").doc("app").get();
  if (!snapshot.exists) return false;
  const settings = snapshot.data() || {};
  return settings.pushEnabled === true &&
    settings.friendAlertEnabled === true;
}

async function getNickname(uid) {
  if (!uid) return "사용자";
  const snapshot = await db.collection("users").doc(uid).get();
  return text(snapshot.data()?.nickname, "사용자");
}

async function notifyUser(params) {
  if (!await isEnabled(params.uid)) return;

  const notificationId = `${params.type}_${params.eventId}`;
  const reference = db.collection("users").doc(params.uid)
      .collection("notifications").doc(notificationId);
  const created = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return false;
    transaction.set(reference, {
      notificationId,
      category: "FRIEND",
      type: params.type,
      title: params.title,
      body: params.body,
      refType: "FRIENDS",
      requestId: params.requestId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
    });
    return true;
  });

  if (!created) return;
  await sendPush(params.uid, {
    title: params.title,
    body: params.body,
    data: {
      category: "FRIEND",
      type: params.type,
      refType: "FRIENDS",
      requestId: params.requestId,
    },
  });
}

const sendFriendNotifications = onDocumentWritten({
  document: "friendRequests/{requestId}",
  region: "asia-northeast3",
}, async (event) => {
  const before = event.data?.before.exists ?
    event.data.before.data() || {} : {};
  const after = event.data?.after.exists ?
    event.data.after.data() || {} : {};
  const beforeStatus = text(before.status).toUpperCase();
  const afterStatus = text(after.status).toUpperCase();
  if (!afterStatus || beforeStatus === afterStatus) return;

  const requestId = event.params.requestId;
  const senderUid = text(after.senderUid);
  const receiverUid = text(after.receiverUid);

  if (afterStatus === "PENDING" && receiverUid) {
    const senderNickname = await getNickname(senderUid);
    await notifyUser({
      uid: receiverUid,
      eventId: `${requestId}_pending`,
      type: "FRIEND_REQUEST",
      title: "친구 요청",
      body: `${senderNickname}님이 친구 요청을 보냈습니다.`,
      requestId,
    });
    return;
  }

  if (beforeStatus === "PENDING" &&
      afterStatus === "ACCEPTED" &&
      senderUid) {
    const receiverNickname = await getNickname(receiverUid);
    await notifyUser({
      uid: senderUid,
      eventId: `${requestId}_accepted`,
      type: "FRIEND_REQUEST_ACCEPTED",
      title: "친구 요청 수락",
      body: `${receiverNickname}님이 친구 요청을 수락했습니다.`,
      requestId,
    });
  }
});

module.exports = {
  sendFriendNotifications,
};
