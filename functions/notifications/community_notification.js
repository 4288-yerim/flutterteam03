"use strict";

const admin = require("firebase-admin");
const {
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const {sendPush} = require("./notification_common");

const db = admin.firestore();
const CATEGORY_FIELD = "communityAlertEnabled";

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
    settings[CATEGORY_FIELD] === true;
}

async function getNickname(uid, fallback = "사용자") {
  if (!uid) return fallback;
  const snapshot = await db.collection("users").doc(uid).get();
  return text(snapshot.data()?.nickname, fallback);
}

async function getPost(postId) {
  const snapshot = await db.collection("posts").doc(postId).get();
  if (!snapshot.exists) return null;
  return snapshot.data() || {};
}

async function notifyPostOwner({
  ownerUid,
  actorUid,
  eventId,
  type,
  title,
  body,
  postId,
  commentId = "",
}) {
  if (!ownerUid || ownerUid === actorUid || !await isEnabled(ownerUid)) {
    return;
  }

  const notificationId = `${type}_${eventId}`;
  const reference = db.collection("users").doc(ownerUid)
      .collection("notifications").doc(notificationId);
  const created = await db.runTransaction(async (transaction) => {
    if ((await transaction.get(reference)).exists) return false;
    transaction.set(reference, {
      notificationId,
      category: "COMMUNITY",
      type,
      title,
      body,
      refType: "COMMUNITY_POST",
      postId,
      commentId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
    });
    return true;
  });

  if (!created) return;
  await sendPush(ownerUid, {
    title,
    body,
    data: {
      category: "COMMUNITY",
      type,
      refType: "COMMUNITY_POST",
      postId,
      commentId,
    },
  });
}

const sendCommunityCommentNotification = onDocumentCreated({
  document: "posts/{postId}/comments/{commentId}",
  region: "asia-northeast3",
}, async (event) => {
  const comment = event.data?.data() || {};
  if (text(comment.commentStatus, "NORMAL") !== "NORMAL") return;

  const postId = event.params.postId;
  const post = await getPost(postId);
  if (!post) return;

  const actorUid = text(comment.writerUid);
  const nickname = text(comment.writerNickname, "사용자");
  const content = text(comment.content, "댓글을 남겼습니다.");
  await notifyPostOwner({
    ownerUid: text(post.writerUid),
    actorUid,
    eventId: `${postId}_${event.params.commentId}`,
    type: "COMMUNITY_COMMENT",
    title: "새 댓글",
    body: `${nickname}님: ${content}`,
    postId,
    commentId: event.params.commentId,
  });
});

const sendCommunityPostLikeNotification = onDocumentCreated({
  document: "postLikes/{userUid}/items/{postId}",
  region: "asia-northeast3",
}, async (event) => {
  const postId = event.params.postId;
  const actorUid = event.params.userUid;
  const post = await getPost(postId);
  if (!post) return;

  const nickname = await getNickname(actorUid);
  await notifyPostOwner({
    ownerUid: text(post.writerUid),
    actorUid,
    eventId: `${actorUid}_${postId}`,
    type: "COMMUNITY_POST_LIKE",
    title: "게시글 좋아요",
    body: `${nickname}님이 회원님의 게시글을 좋아합니다.`,
    postId,
  });
});

const sendCommunityCommentLikeNotification = onDocumentCreated({
  document: "commentLikes/{userUid}/items/{commentId}",
  region: "asia-northeast3",
}, async (event) => {
  const like = event.data?.data() || {};
  const postId = text(like.postId);
  const commentId = event.params.commentId;
  const actorUid = event.params.userUid;
  if (!postId) return;

  const snapshot = await db.collection("posts").doc(postId)
      .collection("comments").doc(commentId).get();
  if (!snapshot.exists) return;

  const nickname = await getNickname(actorUid);
  await notifyPostOwner({
    ownerUid: text(snapshot.data()?.writerUid),
    actorUid,
    eventId: `${actorUid}_${commentId}`,
    type: "COMMUNITY_COMMENT_LIKE",
    title: "댓글 좋아요",
    body: `${nickname}님이 회원님의 댓글을 좋아합니다.`,
    postId,
    commentId,
  });
});

const sendCommunityBookmarkNotification = onDocumentCreated({
  document: "postBookmarks/{userUid}/items/{postId}",
  region: "asia-northeast3",
}, async (event) => {
  const postId = event.params.postId;
  const actorUid = event.params.userUid;
  const post = await getPost(postId);
  if (!post) return;

  const nickname = await getNickname(actorUid);
  await notifyPostOwner({
    ownerUid: text(post.writerUid),
    actorUid,
    eventId: `${actorUid}_${postId}`,
    type: "COMMUNITY_BOOKMARK",
    title: "게시글 저장",
    body: `${nickname}님이 회원님의 게시글을 저장했습니다.`,
    postId,
  });
});

module.exports = {
  sendCommunityCommentNotification,
  sendCommunityPostLikeNotification,
  sendCommunityCommentLikeNotification,
  sendCommunityBookmarkNotification,
};
