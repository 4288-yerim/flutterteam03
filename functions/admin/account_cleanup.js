"use strict";

const admin = require("firebase-admin");
const {
  onSchedule,
} = require("firebase-functions/v2/scheduler");

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const WITHDRAWAL_PENDING = "WITHDRAWAL_PENDING";
const WITHDRAWAL_DELETING = "WITHDRAWAL_DELETING";
const DELETE_BATCH_SIZE = 400;

/**
 * 조회된 문서를 400개씩 나누어 삭제합니다.
 * Firestore batch 제한 500개보다 작게 설정합니다.
 */
async function deleteSnapshotDocuments(snapshot) {
  const documents = snapshot.docs;

  for (
    let start = 0;
    start < documents.length;
    start += DELETE_BATCH_SIZE
  ) {
    const batch = db.batch();

    for (
      const document of documents.slice(
          start,
          start + DELETE_BATCH_SIZE,
      )
    ) {
      batch.delete(document.ref);
    }

    await batch.commit();
  }
}
/**
 * 방장 탈퇴로 종료되는 스터디 한 개를 완전히 삭제합니다.
 */
async function deleteOwnedStudy(studyDocument) {
  const studyId = studyDocument.id;
  const groupReference = studyDocument.ref;
  const chatReference = db
      .collection("chats")
      .doc(studyId);

  /*
   * 해당 스터디의 초대 문서를 먼저 삭제합니다.
   */
  const inviteSnapshot = await db
      .collection("studyGroupInvites")
      .where("groupId", "==", studyId)
      .get();

  await deleteSnapshotDocuments(inviteSnapshot);

  /*
   * 채팅에서 업로드한 사진과 파일을
   * study_chats/{studyId}/ 경로 단위로 삭제합니다.
   */
  await admin
      .storage()
      .bucket()
      .deleteFiles({
        prefix: `study_chats/${studyId}/`,
        force: true,
      });

  /*
   * 채팅 문서와 messages 하위 컬렉션을 삭제합니다.
   */
  await db.recursiveDelete(chatReference);

  /*
   * 스터디와 모든 하위 컬렉션을 재귀 삭제합니다.
   *
   * 포함되는 데이터:
   * members, wrongAnswers, quizzes, answers,
   * studyRecords, subjects, wakeUps 등
   */
  await db.recursiveDelete(groupReference);

  console.log(
      `[withdrawal] 방장 탈퇴로 스터디 종료: ${studyId}`,
  );
}

/**
 * 탈퇴 회원이 방장인 모든 스터디를 종료합니다.
 */
async function deleteOwnedStudies(uid) {
  const snapshot = await db
      .collection("studyGroups")
      .where("ownerUid", "==", uid)
      .get();

  for (const studyDocument of snapshot.docs) {
    await deleteOwnedStudy(studyDocument);
  }
}

/**
 * 탈퇴 회원이 보낸 친구 요청과 문의를 삭제합니다.
 */
async function deleteRelatedDocuments(uid) {
  const [
    sentFriendRequests,
    receivedFriendRequests,
    inquiries,
  ] = await Promise.all([
    db
        .collection("friendRequests")
        .where("senderUid", "==", uid)
        .get(),

    db
        .collection("friendRequests")
        .where("receiverUid", "==", uid)
        .get(),

    db
        .collection("inquiries")
        .where("uid", "==", uid)
        .get(),
  ]);

  await deleteSnapshotDocuments(sentFriendRequests);
  await deleteSnapshotDocuments(receivedFriendRequests);
  await deleteSnapshotDocuments(inquiries);
}

/**
 * 게시글과 댓글은 기존 서비스 안내에 맞춰 삭제하지 않고
 * 작성자 개인정보만 "탈퇴한 사용자"로 익명화합니다.
 */
async function anonymizeCommunityContent(uid) {
  const [posts, comments] = await Promise.all([
    db
        .collection("posts")
        .where("writerUid", "==", uid)
        .get(),

    db
        .collectionGroup("comments")
        .where("writerUid", "==", uid)
        .get(),
  ]);

  const documents = [
    ...posts.docs,
    ...comments.docs,
  ];

  for (
    let start = 0;
    start < documents.length;
    start += DELETE_BATCH_SIZE
  ) {
    const batch = db.batch();

    for (
      const document of documents.slice(
          start,
          start + DELETE_BATCH_SIZE,
      )
    ) {
      batch.update(document.ref, {
        writerUid: "",
        uid: "",
        writerNickname: "탈퇴한 사용자",
        writerProfileImageUrl: "",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}

/**
 * 문서 ID가 사용자 UID인 개인 활동 컬렉션을
 * 하위 컬렉션까지 재귀적으로 삭제합니다.
 */
async function deleteUserActivityRoots(uid) {
  const userRootCollections = [
    "postLikes",
    "commentLikes",
    "postBookmarks",
    "communityPreferences",
    "userStudyLogs",
  ];

  for (const collectionName of userRootCollections) {
    const reference = db
        .collection(collectionName)
        .doc(uid);

    await db.recursiveDelete(reference);
  }
}

/**
 * Firebase Storage 프로필 이미지를 삭제합니다.
 *
 * 현재 앱에서 사용하는 저장 경로:
 * profile_images/{uid}.jpg
 */
async function deleteProfileImage(uid) {
  const file = admin
      .storage()
      .bucket()
      .file(`profile_images/${uid}.jpg`);

  try {
    await file.delete();
  } catch (error) {
    if (error?.code === 404) {
      return;
    }

    throw error;
  }
}

/**
 * Firebase Authentication 계정을 삭제합니다.
 * 이미 삭제된 계정이면 성공한 것으로 처리합니다.
 */
async function deleteAuthenticationUser(uid) {
  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error?.code === "auth/user-not-found") {
      return;
    }

    throw error;
  }
}

/**
 * 삭제 직전에 상태와 예정일을 다시 검사합니다.
 *
 * 사용자가 계정을 복구한 뒤 스케줄러가 늦게 실행되는 경우
 * ACTIVE 회원이 잘못 삭제되는 것을 방지합니다.
 */
async function claimWithdrawalRequest(userReference) {
  return db.runTransaction(
      async (transaction) => {
        const snapshot =
          await transaction.get(userReference);

        if (!snapshot.exists) {
          return false;
        }

        const data = snapshot.data() || {};

        const status = String(
            data.status || "",
        )
            .trim()
            .toUpperCase();

        if (
          status !== WITHDRAWAL_PENDING &&
          status !== WITHDRAWAL_DELETING
        ) {
          return false;
        }

        const scheduledAt =
          data.withdrawalScheduledAt;

        if (
          !scheduledAt ||
          typeof scheduledAt.toMillis !== "function" ||
          scheduledAt.toMillis() > Date.now()
        ) {
          return false;
        }

        transaction.update(userReference, {
          status: WITHDRAWAL_DELETING,
          withdrawalDeletionStartedAt:
            FieldValue.serverTimestamp(),
          withdrawalDeletionError:
            FieldValue.delete(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        return true;
      },
  );
}

/**
 * 회원 한 명의 최종 탈퇴를 처리합니다.
 */
async function deleteExpiredAccount(
    userDocument,
) {
  const uid = userDocument.id;

  const userReference = db
      .collection("users")
      .doc(uid);

  const claimed =
    await claimWithdrawalRequest(
        userReference,
    );

  if (!claimed) {
    return;
  }

  try {
    /*
     * 방장으로 운영 중인 스터디를 먼저 종료합니다.
     */
    await deleteOwnedStudies(uid);

    /*
     * 1. 게시글과 댓글의 작성자를 익명화합니다.
     */
    await anonymizeCommunityContent(uid);

    /*
     * 2. 친구 요청과 문의를 삭제합니다.
     */
    await deleteRelatedDocuments(uid);

    /*
     * 3. 좋아요, 북마크 등 UID 기반 개인 데이터를 삭제합니다.
     */
    await deleteUserActivityRoots(uid);

    /*
     * 4. Storage 프로필 이미지를 삭제합니다.
     */
    await deleteProfileImage(uid);

    /*
     * 5. Firebase Authentication 계정을 삭제합니다.
     */
    await deleteAuthenticationUser(uid);

    /*
     * 6. users/{uid}와 모든 하위 컬렉션을 삭제합니다.
     *
     * 반드시 마지막에 실행해야 중간 실패 시
     * 다음 스케줄에서 다시 처리할 수 있습니다.
     */
    await db.recursiveDelete(
        userReference,
    );

    console.log(
        `[withdrawal] 최종 탈퇴 처리 완료: ${uid}`,
    );
  } catch (error) {
    console.error(
        `[withdrawal] 최종 탈퇴 처리 실패: ${uid}`,
        error,
    );

    /*
     * 사용자 문서가 아직 남아 있다면 PENDING으로 되돌려
     * 다음 예약 실행에서 다시 시도할 수 있게 합니다.
     */
    const currentUser =
      await userReference.get();

    if (currentUser.exists) {
      await userReference.set(
          {
            status: WITHDRAWAL_PENDING,
            withdrawalDeletionError:
              String(
                  error?.message ||
                  error ||
                  "unknown",
              ).slice(0, 500),
            withdrawalDeletionFailedAt:
              FieldValue.serverTimestamp(),
            updatedAt:
              FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          },
      );
    }

    throw error;
  }
}

/**
 * 매일 오전 3시 10분에 실행됩니다.
 *
 * 한 번에 최대 100명을 처리하며,
 * 남은 회원은 다음 실행에서 처리합니다.
 */
const deleteExpiredWithdrawalAccounts =
  onSchedule(
      {
        schedule: "every day 03:10",
        timeZone: "Asia/Seoul",
        region: "asia-northeast3",
        timeoutSeconds: 540,
        memory: "512MiB",
        maxInstances: 1,
        retryCount: 3,
      },
      async () => {
        const now =
          admin.firestore.Timestamp.now();

        const snapshot = await db
            .collection("users")
            .where(
                "status",
                "in",
                [
                  WITHDRAWAL_PENDING,
                  WITHDRAWAL_DELETING,
                ],
            )
            .where(
                "withdrawalScheduledAt",
                "<=",
                now,
            )
            .limit(100)
            .get();

        console.log(
            `[withdrawal] 처리 대상: ${snapshot.size}명`,
        );

        for (const userDocument of snapshot.docs) {
          await deleteExpiredAccount(
              userDocument,
          );
        }
      },
  );

module.exports = {
  deleteExpiredWithdrawalAccounts,
};