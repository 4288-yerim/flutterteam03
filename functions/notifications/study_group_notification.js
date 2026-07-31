"use strict";

const admin = require("firebase-admin");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {sendPush} = require("./notification_common");

const db = admin.firestore();
const CATEGORY_FIELD = "studyGroupAlertEnabled";
const NOTICE_FIELD = "studyNoticeAlertEnabled";
const JOIN_REQUEST_FIELD = "studyJoinApprovalAlertEnabled";
const NEW_MEMBER_FIELD = "studyNewMemberAlertEnabled";
const CHAT_FIELD = "studyChatsAlertEnabled";

function text(value, fallback = "") {
  const result = String(value || "").trim();
  return result || fallback;
}

async function isEnabled(uid, subTypeField) {
  if (!uid) return false;
  const snapshot = await db.collection("users").doc(uid)
      .collection("settings").doc("app").get();
  if (!snapshot.exists) return false;
  const settings = snapshot.data() || {};
  return settings.pushEnabled === true &&
    settings[CATEGORY_FIELD] === true &&
    settings[subTypeField] === true;
}

async function getGroup(studyId) {
  const snapshot = await db.collection("studyGroups").doc(studyId).get();
  if (!snapshot.exists) return null;
  const data = snapshot.data() || {};
  return {
    groupName: text(data.groupName, "스터디"),
    ownerUid: text(data.ownerUid),
  };
}

async function getActiveMemberUids(studyId) {
  const snapshot = await db.collection("studyGroups").doc(studyId)
      .collection("members").where("status", "==", "ACTIVE").get();
  return [...new Set(snapshot.docs.map((document) =>
    text(document.data()?.uid, document.id)).filter(Boolean))];
}

async function createNotification(params) {
  const notificationId = `${params.type}_${params.eventId}`;
  const reference = db.collection("users").doc(params.uid)
      .collection("notifications").doc(notificationId);
  return db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return false;
    transaction.set(reference, {
      notificationId,
      category: "STUDY_GROUP",
      type: params.type,
      title: params.title,
      body: params.body,
      refType: params.refType,
      studyId: params.studyId,
      groupName: params.groupName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
    });
    return true;
  });
}

async function notifyUser(params) {
  if (!await isEnabled(params.uid, params.settingField)) return;
  if (!await createNotification(params)) return;
  await sendPush(params.uid, {
    title: params.title,
    body: params.body,
    data: {
      category: "STUDY_GROUP",
      type: params.type,
      refType: params.refType,
      studyId: params.studyId,
      groupName: params.groupName,
    },
  });
}

async function notifyUsers(uids, params) {
  await Promise.all([...new Set(uids)].map((uid) =>
    notifyUser({uid, ...params}).catch((error) => {
      console.error(
          `[스터디 알림 실패] uid=${uid}, type=${params.type}`,
          error,
      );
    })));
}

const sendStudyNoticeNotification = onDocumentUpdated({
  document: "studyGroups/{studyId}",
  region: "asia-northeast3",
}, async (event) => {
  const before = event.data?.before.data() || {};
  const after = event.data?.after.data() || {};
  const beforeUpdatedAt = before.noticeUpdatedAt?.toMillis?.() || 0;
  const afterUpdatedAt = after.noticeUpdatedAt?.toMillis?.() || 0;
  if (!afterUpdatedAt || beforeUpdatedAt === afterUpdatedAt) return;

  const studyId = event.params.studyId;
  const groupName = text(after.groupName, "스터디");
  const ownerUid = text(after.ownerUid);
  const recipients = (await getActiveMemberUids(studyId))
      .filter((uid) => uid !== ownerUid);
  await notifyUsers(recipients, {
    settingField: NOTICE_FIELD,
    eventId: `${studyId}_${event.id}`,
    type: "STUDY_NOTICE",
    title: "스터디 공지",
    body: `${groupName} 공지가 변경되었습니다.`,
    refType: "STUDY_ROOM",
    studyId,
    groupName,
  });
});

const sendStudyMembershipNotifications = onDocumentWritten({
  document: "studyGroups/{studyId}/members/{memberUid}",
  region: "asia-northeast3",
}, async (event) => {
  const before = event.data?.before.exists ?
    event.data.before.data() || {} : {};
  const after = event.data?.after.exists ?
    event.data.after.data() || {} : {};
  const beforeStatus = text(before.status);
  const afterStatus = text(after.status);
  if (!afterStatus || beforeStatus === afterStatus) return;

  const studyId = event.params.studyId;
  const memberUid = event.params.memberUid;
  const memberNickname = text(after.nickname, "사용자");
  const group = await getGroup(studyId);
  if (!group) return;

  if (afterStatus === "PENDING" && group.ownerUid) {
    await notifyUser({
      uid: group.ownerUid,
      settingField: JOIN_REQUEST_FIELD,
      eventId: `${studyId}_${memberUid}_${event.id}`,
      type: "STUDY_JOIN_REQUEST",
      title: "스터디 가입 신청",
      body: `${memberNickname}이 ${group.groupName}에 가입신청 했습니다.`,
      refType: "STUDY_JOIN_REQUESTS",
      studyId,
      groupName: group.groupName,
    });
    return;
  }

  if (afterStatus !== "ACTIVE" || after.role === "OWNER") return;

  if (beforeStatus === "PENDING") {
    await notifyUser({
      uid: memberUid,
      settingField: JOIN_REQUEST_FIELD,
      eventId: `${studyId}_${memberUid}_approved_${event.id}`,
      type: "STUDY_JOIN_APPROVED",
      title: "스터디 가입 승인",
      body: `${group.groupName} 가입 신청이 승인되었습니다.`,
      refType: "STUDY_ROOM",
      studyId,
      groupName: group.groupName,
    });
  }

  const recipients = (await getActiveMemberUids(studyId))
      .filter((uid) => uid !== group.ownerUid && uid !== memberUid);
  await notifyUsers(recipients, {
    settingField: NEW_MEMBER_FIELD,
    eventId: `${studyId}_${memberUid}_${event.id}`,
    type: "STUDY_NEW_MEMBER",
    title: "스터디 새 멤버",
    body: `${memberNickname}이 ${group.groupName}에 가입했습니다.`,
    refType: "STUDY_ROOM",
    studyId,
    groupName: group.groupName,
  });
});

const sendStudyChatNotification = onDocumentCreated({
  document: "chats/{studyId}/messages/{messageId}",
  region: "asia-northeast3",
}, async (event) => {
  const message = event.data?.data() || {};
  if (message.isDeleted === true || text(message.messageType) === "DELETED") {
    return;
  }

  const studyId = event.params.studyId;
  const senderUid = text(message.senderUid);
  const senderNickname = text(message.senderNickname, "사용자");
  const sentMessage = text(message.message, "새 메시지");
  const group = await getGroup(studyId);
  if (!group) return;

  // Let clients displaying this chat update readBy before selecting targets.
  await new Promise((resolve) => setTimeout(resolve, 3000));
  const latestSnapshot = await event.data.ref.get();
  const latestMessage = latestSnapshot.data() || message;
  const readBy = Array.isArray(latestMessage.readBy) ?
    latestMessage.readBy.map((uid) => text(uid)).filter(Boolean) :
    [];

  const recipients = (await getActiveMemberUids(studyId))
      .filter((uid) => uid !== senderUid && !readBy.includes(uid));
  await notifyUsers(recipients, {
    settingField: CHAT_FIELD,
    eventId: `${studyId}_${event.params.messageId}`,
    type: "STUDY_CHAT",
    title: `${group.groupName} 새로운 채팅이 있습니다.`,
    body: `${senderNickname}: ${sentMessage}`,
    refType: "STUDY_CHAT",
    studyId,
    groupName: group.groupName,
  });
});

module.exports = {
  sendStudyNoticeNotification,
  sendStudyMembershipNotifications,
  sendStudyChatNotification,
};
