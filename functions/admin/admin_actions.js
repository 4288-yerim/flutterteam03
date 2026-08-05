"use strict";

const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const options = {
  region: "asia-northeast3",
  timeoutSeconds: 60,
  memory: "256MiB",
  invoker: "public",
};

function text(value) {
  return String(value || "").trim();
}

function upper(value) {
  return text(value).toUpperCase();
}

function requireId(value, label) {
  const id = text(value);
  if (!id || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${label}이 올바르지 않습니다.`);
  }
  return id;
}

function requireOperationId(value) {
  const id = text(value);
  if (!/^[A-Za-z0-9_-]{10,100}$/.test(id)) {
    throw new HttpsError("invalid-argument", "작업 식별자가 필요합니다.");
  }
  return id;
}

async function requireAdministrator(uid) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const snapshot = await db.collection("users").doc(uid).get();
  const data = snapshot.data() || {};
  if (!snapshot.exists || upper(data.role) !== "ADMIN") {
    throw new HttpsError("permission-denied", "관리자 권한이 필요합니다.");
  }
  return {
    uid,
    name: text(data.nickname) || text(data.email) || uid,
  };
}

function logReference(scope, operationId, suffix) {
  const tail = suffix ? `-${suffix}` : "";
  return db.collection("adminLogs").doc(`${scope}-${operationId}${tail}`);
}

function createLog(transaction, reference, data) {
  transaction.create(reference, {
    schemaVersion: 1,
    adminUid: data.administrator.uid,
    adminName: data.administrator.name,
    actionType: data.actionType,
    targetType: data.targetType,
    targetId: data.targetId || null,
    description: data.description,
    beforeData: data.beforeData || null,
    afterData: data.afterData || null,
    relatedReportId: data.relatedReportId || null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function readTargetIds(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => {
    if (item && typeof item === "object") return text(item.id);
    return text(item);
  }).filter(Boolean);
}

function count(value) {
  return typeof value === "number" && Number.isFinite(value) ?
    Math.trunc(value) : 0;
}

const setAdminMemberSuspension = onCall(options, async (request) => {
  const administrator = await requireAdministrator(request.auth?.uid);
  const operationId = requireOperationId(request.data?.operationId);
  const targetUid = requireId(request.data?.targetUid, "회원 UID");
  if (typeof request.data?.suspend !== "boolean") {
    throw new HttpsError("invalid-argument", "정지 여부가 필요합니다.");
  }

  const suspend = request.data.suspend;
  const nextStatus = suspend ? "SUSPENDED" : "ACTIVE";
  const userRef = db.collection("users").doc(targetUid);
  const logRef = logReference("member", operationId);

  return db.runTransaction(async (transaction) => {
    const [oldLog, user] = await Promise.all([
      transaction.get(logRef),
      transaction.get(userRef),
    ]);
    if (oldLog.exists) return {success: true, alreadyApplied: true};
    if (!user.exists) {
      throw new HttpsError("not-found", "회원을 찾을 수 없습니다.");
    }

    const beforeStatus = upper(user.data()?.status) || "ACTIVE";
    if (beforeStatus === nextStatus) {
      throw new HttpsError(
          "failed-precondition",
          suspend ? "이미 정지된 회원입니다." : "이미 활성 회원입니다.",
      );
    }

    transaction.update(userRef, {
      status: nextStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });
    createLog(transaction, logRef, {
      administrator,
      actionType: suspend ? "SUSPEND_USER" : "UNSUSPEND_USER",
      targetType: "USER",
      targetId: targetUid,
      description: suspend ? "회원 이용 정지" : "회원 이용 정지 해제",
      beforeData: {status: beforeStatus},
      afterData: {status: nextStatus},
    });
    return {success: true, alreadyApplied: false};
  });
});

const processAdminReport = onCall(options, async (request) => {
  const administrator = await requireAdministrator(request.auth?.uid);
  const operationId = requireOperationId(request.data?.operationId);
  const reportId = requireId(request.data?.reportId, "신고 ID");
  const decision = upper(request.data?.decision);
  if (!(["APPROVE", "REJECT"].includes(decision))) {
    throw new HttpsError("invalid-argument", "처리 결과가 올바르지 않습니다.");
  }
  if (typeof request.data?.hideContent !== "boolean") {
    throw new HttpsError("invalid-argument", "숨김 여부가 필요합니다.");
  }

  const approved = decision === "APPROVE";
  const reportRef = db.collection("reports").doc(reportId);
  const decisionLogRef = logReference("report", operationId, "decision");
  const contentLogRef = logReference("report", operationId, "content");

  return db.runTransaction(async (transaction) => {
    const [oldLog, report] = await Promise.all([
      transaction.get(decisionLogRef),
      transaction.get(reportRef),
    ]);
    if (oldLog.exists) return {success: true, alreadyApplied: true};
    if (!report.exists) {
      throw new HttpsError("not-found", "신고를 찾을 수 없습니다.");
    }

    const reportData = report.data() || {};
    const beforeStatus = upper(reportData.status) || "PENDING";
    if (beforeStatus !== "PENDING") {
      throw new HttpsError("failed-precondition", "이미 처리된 신고입니다.");
    }

    const targetType = upper(reportData.targetType) || "UNKNOWN";
    const ids = readTargetIds(reportData.targetId);
    const targetUid = text(reportData.targetUid);
    const postTarget = targetType === "POST" && ids.length >= 1;
    const commentTarget = targetType === "COMMENT" && ids.length >= 2;
    const hideContent = approved && request.data.hideContent &&
      (postTarget || commentTarget);
    let postRef;
    let post;
    let commentRef;
    let comment;

    if (hideContent) {
      postRef = db.collection("posts").doc(ids[0]);
      if (commentTarget) {
        commentRef = postRef.collection("comments").doc(ids[1]);
        [post, comment] = await Promise.all([
          transaction.get(postRef),
          transaction.get(commentRef),
        ]);
      } else {
        post = await transaction.get(postRef);
      }
      if (!post.exists || (commentRef && !comment.exists)) {
        throw new HttpsError("not-found", "신고 대상을 찾을 수 없습니다.");
      }
    }

    const reportActions = [];
    if (!approved) {
      reportActions.push("NONE");
    } else {
      if (targetUid) reportActions.push("WARNING");
      if (hideContent) reportActions.push("DELETE");
      if (reportActions.length === 0) reportActions.push("NONE");
    }
    const nextStatus = approved ? "RESOLVED" : "REJECTED";

    transaction.update(reportRef, {
      status: nextStatus,
      actionType: reportActions,
      processedBy: administrator.uid,
      processedAt: FieldValue.serverTimestamp(),
    });

    if (approved && targetUid) {
      const counters = {
        reportCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (targetType === "POST") {
        counters.postReportCount = FieldValue.increment(1);
      } else if (targetType === "COMMENT") {
        counters.commentsReportCount = FieldValue.increment(1);
      } else if (targetType === "STUDY_MEMBER") {
        counters.studyMemberReportCount = FieldValue.increment(1);
      }
      transaction.update(db.collection("users").doc(targetUid), counters);
    }

    createLog(transaction, decisionLogRef, {
      administrator,
      actionType: approved ? "APPROVE_REPORT" : "REJECT_REPORT",
      targetType: "REPORT",
      targetId: reportId,
      description: approved ? "신고 승인" : "신고 반려",
      beforeData: {status: beforeStatus},
      afterData: {status: nextStatus, actionType: reportActions},
      relatedReportId: reportId,
    });

    if (hideContent && postTarget) {
      const data = post.data() || {};
      transaction.update(postRef, {
        postStatus: "DELETED",
        visibility: "PRIVATE",
        deletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: "REPORT_HIDDEN",
        moderationReportId: reportId,
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      createLog(transaction, contentLogRef, {
        administrator,
        actionType: "HIDE_POST",
        targetType: "POST",
        targetId: ids[0],
        description: "신고 승인에 따른 게시글 숨김",
        beforeData: {
          postStatus: upper(data.postStatus) || "NORMAL",
          visibility: upper(data.visibility) || "PUBLIC",
        },
        afterData: {postStatus: "DELETED", visibility: "PRIVATE"},
        relatedReportId: reportId,
      });
    } else if (hideContent && commentTarget) {
      const data = comment.data() || {};
      const rootAccepted = !text(data.parentCommentId) &&
        data.isAccepted === true;
      transaction.update(commentRef, {
        commentStatus: "DELETED",
        isAccepted: false,
        moderationPreviousIsAccepted: data.isAccepted === true,
        deletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: "REPORT_HIDDEN",
        moderationBatchId: null,
        moderationReportId: reportId,
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      const postUpdates = {
        commentCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (rootAccepted) postUpdates.questionStatus = "WAITING";
      transaction.update(postRef, postUpdates);
      createLog(transaction, contentLogRef, {
        administrator,
        actionType: "HIDE_COMMENT",
        targetType: "COMMENT",
        targetId: ids[1],
        description: "신고 승인에 따른 댓글 숨김",
        beforeData: {
          postId: ids[0],
          commentStatus: upper(data.commentStatus) || "NORMAL",
          isAccepted: data.isAccepted === true,
        },
        afterData: {
          postId: ids[0],
          commentStatus: "DELETED",
          isAccepted: false,
        },
        relatedReportId: reportId,
      });
    }
    return {success: true, alreadyApplied: false};
  });
});

const reopenAdminReport = onCall(options, async (request) => {
  const administrator = await requireAdministrator(request.auth?.uid);
  const operationId = requireOperationId(request.data?.operationId);
  const reportId = requireId(request.data?.reportId, "신고 ID");
  const reportRef = db.collection("reports").doc(reportId);
  const decisionLogRef = logReference("reopen", operationId, "decision");
  const contentLogRef = logReference("reopen", operationId, "content");

  return db.runTransaction(async (transaction) => {
    const [oldLog, report] = await Promise.all([
      transaction.get(decisionLogRef),
      transaction.get(reportRef),
    ]);
    if (oldLog.exists) return {success: true, alreadyApplied: true};
    if (!report.exists) {
      throw new HttpsError("not-found", "신고를 찾을 수 없습니다.");
    }

    const reportData = report.data() || {};
    const beforeStatus = upper(reportData.status);
    if (beforeStatus !== "RESOLVED" && beforeStatus !== "REJECTED") {
      throw new HttpsError(
          "failed-precondition",
          "처리 완료된 신고만 취소할 수 있습니다.",
      );
    }

    const approved = beforeStatus === "RESOLVED";
    const actions = Array.isArray(reportData.actionType) ?
      reportData.actionType.map(upper) : [];
    const contentWasHidden = approved && actions.includes("DELETE");
    const targetType = upper(reportData.targetType) || "UNKNOWN";
    const ids = readTargetIds(reportData.targetId);
    const targetUid = text(reportData.targetUid);

    let userRef;
    let user;
    if (approved && targetUid) {
      userRef = db.collection("users").doc(targetUid);
      user = await transaction.get(userRef);
    }

    let postRef;
    let post;
    let contentRef;
    let content;
    if (contentWasHidden) {
      if (targetType === "POST" && ids.length >= 1) {
        postRef = db.collection("posts").doc(ids[0]);
        contentRef = postRef;
        post = await transaction.get(postRef);
        content = post;
      } else if (targetType === "COMMENT" && ids.length >= 2) {
        postRef = db.collection("posts").doc(ids[0]);
        contentRef = postRef.collection("comments").doc(ids[1]);
        [post, content] = await Promise.all([
          transaction.get(postRef),
          transaction.get(contentRef),
        ]);
      } else {
        throw new HttpsError(
            "failed-precondition",
            "숨김 콘텐츠 경로를 확인할 수 없습니다.",
        );
      }
      if (!post.exists || !content.exists) {
        throw new HttpsError(
            "not-found",
            "복구할 신고 대상 콘텐츠를 찾을 수 없습니다.",
        );
      }
    }

    transaction.update(reportRef, {
      status: "PENDING",
      actionType: [],
      processedBy: null,
      processedAt: null,
    });

    if (approved && user?.exists) {
      const userData = user.data() || {};
      const counters = {
        reportCount: Math.max(0, count(userData.reportCount) - 1),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (targetType === "POST") {
        counters.postReportCount = Math.max(
            0,
            count(userData.postReportCount) - 1,
        );
      } else if (targetType === "COMMENT") {
        counters.commentsReportCount = Math.max(
            0,
            count(userData.commentsReportCount) - 1,
        );
      } else if (targetType === "STUDY_MEMBER") {
        counters.studyMemberReportCount = Math.max(
            0,
            count(userData.studyMemberReportCount) - 1,
        );
      }
      transaction.update(userRef, counters);
    }

    createLog(transaction, decisionLogRef, {
      administrator,
      actionType: "REOPEN_REPORT",
      targetType: "REPORT",
      targetId: reportId,
      description: "신고 처리 취소",
      beforeData: {status: beforeStatus, actionType: actions},
      afterData: {status: "PENDING", actionType: []},
      relatedReportId: reportId,
    });

    if (contentWasHidden && targetType === "POST") {
      const data = content.data() || {};
      const moderationStatus = upper(data.moderationStatus);
      const moderationReportId = text(data.moderationReportId);
      const legacyReportHidden = !moderationStatus &&
        upper(data.postStatus) === "DELETED" &&
        upper(data.visibility) === "PRIVATE";
      if (!legacyReportHidden &&
          (moderationStatus !== "REPORT_HIDDEN" ||
            moderationReportId !== reportId)) {
        throw new HttpsError(
            "failed-precondition",
            "다른 관리자 작업으로 변경된 게시글은 자동 복구할 수 없습니다.",
        );
      }
      transaction.update(contentRef, {
        postStatus: "NORMAL",
        visibility: "PUBLIC",
        deletedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: "RESTORED",
        moderationReportId: null,
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      createLog(transaction, contentLogRef, {
        administrator,
        actionType: "RESTORE_POST",
        targetType: "POST",
        targetId: ids[0],
        description: "신고 처리 취소에 따른 게시글 복구",
        beforeData: {
          postStatus: upper(data.postStatus),
          visibility: upper(data.visibility),
          moderationStatus,
        },
        afterData: {
          postStatus: "NORMAL",
          visibility: "PUBLIC",
          moderationStatus: "RESTORED",
        },
        relatedReportId: reportId,
      });
    } else if (contentWasHidden && targetType === "COMMENT") {
      const data = content.data() || {};
      if (upper(data.moderationStatus) !== "REPORT_HIDDEN" ||
          text(data.moderationReportId) !== reportId) {
        throw new HttpsError(
            "failed-precondition",
            "다른 관리자 작업으로 변경된 댓글은 자동 복구할 수 없습니다.",
        );
      }
      const restoreAccepted = data.moderationPreviousIsAccepted === true;
      transaction.update(contentRef, {
        commentStatus: "NORMAL",
        isAccepted: restoreAccepted,
        moderationPreviousIsAccepted: null,
        deletedAt: null,
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: "RESTORED",
        moderationReportId: null,
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      if (!text(data.parentCommentId) && restoreAccepted) {
        transaction.update(postRef, {
          questionStatus: "RESOLVED",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      createLog(transaction, contentLogRef, {
        administrator,
        actionType: "RESTORE_COMMENT",
        targetType: "COMMENT",
        targetId: ids[1],
        description: "신고 처리 취소에 따른 댓글 복구",
        beforeData: {
          postId: ids[0],
          commentStatus: upper(data.commentStatus),
          isAccepted: data.isAccepted === true,
          moderationStatus: upper(data.moderationStatus),
        },
        afterData: {
          postId: ids[0],
          commentStatus: "NORMAL",
          isAccepted: restoreAccepted,
          moderationStatus: "RESTORED",
        },
        relatedReportId: reportId,
      });
    }

    return {success: true, alreadyApplied: false};
  });
});

const moderateAdminCommunityContent = onCall(options, async (request) => {
  const administrator = await requireAdministrator(request.auth?.uid);
  const operationId = requireOperationId(request.data?.operationId);
  const targetType = upper(request.data?.targetType);
  const action = upper(request.data?.action);
  if (!(["POST", "COMMENT"].includes(targetType))) {
    throw new HttpsError("invalid-argument", "대상 종류가 올바르지 않습니다.");
  }
  if (!(["HIDE", "RESTORE"].includes(action))) {
    throw new HttpsError("invalid-argument", "작업 종류가 올바르지 않습니다.");
  }

  const postId = requireId(request.data?.postId, "게시글 ID");
  const commentId = targetType === "COMMENT" ?
    requireId(request.data?.commentId, "댓글 ID") : null;
  const postRef = db.collection("posts").doc(postId);
  const targetRef = targetType === "POST" ?
    postRef : postRef.collection("comments").doc(commentId);
  const auditRef = logReference("community", operationId);

  return db.runTransaction(async (transaction) => {
    const [oldLog, target] = await Promise.all([
      transaction.get(auditRef),
      transaction.get(targetRef),
    ]);
    if (oldLog.exists) return {success: true, alreadyApplied: true};
    if (!target.exists) {
      throw new HttpsError("not-found", "관리 대상을 찾을 수 없습니다.");
    }
    const data = target.data() || {};

    if (targetType === "POST") {
      const status = upper(data.postStatus) || "NORMAL";
      const visibility = upper(data.visibility) || "PUBLIC";
      const moderation = upper(data.moderationStatus);
      if (action === "HIDE" &&
          (status !== "NORMAL" || visibility !== "PUBLIC")) {
        throw new HttpsError("failed-precondition", "이미 숨긴 게시글입니다.");
      }
      if (action === "RESTORE" && moderation !== "HIDDEN") {
        throw new HttpsError(
            "failed-precondition",
            "관리자가 숨긴 게시글만 복구할 수 있습니다.",
        );
      }
      const hiding = action === "HIDE";
      transaction.update(postRef, {
        postStatus: hiding ? "DELETED" : "NORMAL",
        visibility: hiding ? "PRIVATE" : "PUBLIC",
        deletedAt: hiding ? FieldValue.serverTimestamp() : null,
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: hiding ? "HIDDEN" : "RESTORED",
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      createLog(transaction, auditRef, {
        administrator,
        actionType: hiding ? "HIDE_POST" : "RESTORE_POST",
        targetType: "POST",
        targetId: postId,
        description: hiding ? "게시글 직접 숨김" : "게시글 직접 복구",
        beforeData: {postStatus: status, visibility, moderationStatus: moderation},
        afterData: {
          postStatus: hiding ? "DELETED" : "NORMAL",
          visibility: hiding ? "PRIVATE" : "PUBLIC",
          moderationStatus: hiding ? "HIDDEN" : "RESTORED",
        },
      });
      return {success: true, alreadyApplied: false};
    }

    const status = upper(data.commentStatus) || "NORMAL";
    const moderation = upper(data.moderationStatus);
    if (action === "HIDE" && status !== "NORMAL") {
      throw new HttpsError("failed-precondition", "이미 숨긴 댓글입니다.");
    }
    if (action === "RESTORE" && moderation !== "HIDDEN") {
      throw new HttpsError(
          "failed-precondition",
          "관리자가 숨긴 댓글만 복구할 수 있습니다.",
      );
    }

    let restored = [target];
    if (action === "RESTORE" && text(data.moderationBatchId)) {
      const query = postRef.collection("comments")
          .where("moderationBatchId", "==", text(data.moderationBatchId));
      const matches = await transaction.get(query);
      restored = matches.docs.filter((item) =>
        upper(item.data()?.moderationStatus) === "HIDDEN",
      );
    }
    if (action === "RESTORE" && restored.length === 0) {
      throw new HttpsError("failed-precondition", "복구할 댓글이 없습니다.");
    }

    if (action === "HIDE") {
      const rootAccepted = !text(data.parentCommentId) &&
        data.isAccepted === true;
      transaction.update(targetRef, {
        commentStatus: "DELETED",
        isAccepted: false,
        deletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        moderationStatus: "HIDDEN",
        moderationBatchId: `admin-${operationId}`,
        moderationReportId: null,
        moderatedBy: administrator.uid,
        moderatedAt: FieldValue.serverTimestamp(),
      });
      const postUpdates = {
        commentCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (rootAccepted) postUpdates.questionStatus = "WAITING";
      transaction.update(postRef, postUpdates);
    } else {
      for (const item of restored) {
        transaction.update(item.ref, {
          commentStatus: "NORMAL",
          deletedAt: null,
          updatedAt: FieldValue.serverTimestamp(),
          moderationStatus: "RESTORED",
          moderatedBy: administrator.uid,
          moderatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.update(postRef, {
        commentCount: FieldValue.increment(restored.length),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    createLog(transaction, auditRef, {
      administrator,
      actionType: action === "HIDE" ? "HIDE_COMMENT" : "RESTORE_COMMENT",
      targetType: "COMMENT",
      targetId: commentId,
      description: action === "HIDE" ? "댓글 직접 숨김" : "댓글 직접 복구",
      beforeData: {
        postId,
        commentStatus: status,
        moderationStatus: moderation,
        isAccepted: data.isAccepted === true,
      },
      afterData: {
        postId,
        commentStatus: action === "HIDE" ? "DELETED" : "NORMAL",
        moderationStatus: action === "HIDE" ? "HIDDEN" : "RESTORED",
        restoredCount: action === "RESTORE" ? restored.length : 0,
      },
    });
    return {success: true, alreadyApplied: false};
  });
});

module.exports = {
  setAdminMemberSuspension,
  processAdminReport,
  reopenAdminReport,
  moderateAdminCommunityContent,
};
