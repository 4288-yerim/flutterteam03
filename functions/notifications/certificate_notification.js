"use strict";

const admin = require("firebase-admin");
const {
  onSchedule,
} = require("firebase-functions/v2/scheduler");

const {
  canSend,
  sendPush,
} = require("./notification_common");

const db = admin.firestore();

const CERTIFICATE_CATEGORY_FIELD =
    "certificateAlertEnabled";

const ALERT_CONFIGS = {
  APPLICATION_START: {
    dateField: "applicationStartAlertDate",
    settingField:
        "applicationStartAlertEnabled",
  },

  APPLICATION_END_D1: {
    dateField: "applicationEndD1AlertDate",
    settingField:
        "applicationEndD1AlertEnabled",
  },

  EXAM_D7: {
    dateField: "examD7AlertDate",
    settingField: "examD7AlertEnabled",
  },

  EXAM_D1: {
    dateField: "examD1AlertDate",
    settingField: "examD1AlertEnabled",
  },

  EXAM_DAY: {
    dateField: "examDayAlertDate",
    settingField: "examDayAlertEnabled",
  },

  RESULT: {
    dateField: "resultAlertDate",
    settingField: "resultAlertEnabled",
  },
};

function getTodayRangeInSeoul() {
  const formatter = new Intl.DateTimeFormat(
      "en-CA",
      {
        timeZone: "Asia/Seoul",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      },
  );

  const parts = formatter.formatToParts(
      new Date(),
  );

  const values = {};

  for (const part of parts) {
    if (part.type !== "literal") {
      values[part.type] = part.value;
    }
  }

  const year = Number(values.year);
  const month = Number(values.month);
  const day = Number(values.day);

  const startMillis = Date.UTC(
      year,
      month - 1,
      day,
      -9,
      0,
      0,
      0,
  );

  const endMillis =
      startMillis + 24 * 60 * 60 * 1000;

  return {
    start:
        admin.firestore.Timestamp.fromMillis(
            startMillis,
        ),

    end:
        admin.firestore.Timestamp.fromMillis(
            endMillis,
        ),

    dateKey:
        `${year}` +
        `${String(month).padStart(2, "0")}` +
        `${String(day).padStart(2, "0")}`,
  };
}

function formatKoreanDate(value) {
  if (!value) {
    return "";
  }

  const date =
      typeof value.toDate === "function" ?
        value.toDate() :
        value;

  if (!(date instanceof Date)) {
    return "";
  }

  return new Intl.DateTimeFormat(
      "ko-KR",
      {
        timeZone: "Asia/Seoul",
        year: "numeric",
        month: "long",
        day: "numeric",
      },
  ).format(date);
}

function getExamTypeName(examType) {
  return examType === "WRITTEN" ?
    "필기시험" :
    "실기시험";
}

function buildNotificationMessage(
    alertType,
    goal,
) {
  const certificateName =
      String(
          goal.certificateName || "자격증",
      ).trim();

  const targetRound =
      String(goal.targetRound || "").trim();

  const examTypeName =
      getExamTypeName(goal.targetExamType);

  const roundText = targetRound ?
    ` ${targetRound}` :
    "";

  switch (alertType) {
    case "APPLICATION_START": {
      const date = formatKoreanDate(
          goal.targetRegistrationStartDate,
      );

      return {
        title: "원서접수가 시작됐어요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName} 원서접수가 ` +
            `오늘 시작됩니다.` +
            (date ? ` 접수 시작일은 ${date}입니다.` : ""),
      };
    }

    case "APPLICATION_END_D1": {
      const date = formatKoreanDate(
          goal.targetRegistrationEndDate,
      );

      return {
        title: "원서접수가 내일 마감돼요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName} 원서접수가 ` +
            `내일 마감됩니다.` +
            (date ? ` 마감일은 ${date}입니다.` : ""),
      };
    }

    case "EXAM_D7": {
      const date = formatKoreanDate(
          goal.targetExamDate,
      );

      return {
        title: "시험까지 7일 남았어요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName}까지 7일 남았습니다.` +
            (date ? ` 시험일은 ${date}입니다.` : ""),
      };
    }

    case "EXAM_D1": {
      const date = formatKoreanDate(
          goal.targetExamDate,
      );

      return {
        title: "시험이 내일이에요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName}이 내일 진행됩니다.` +
            (date ? ` 시험일은 ${date}입니다.` : ""),
      };
    }

    case "EXAM_DAY": {
      return {
        title: "오늘은 시험일이에요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName}이 오늘 진행됩니다. ` +
            "준비물을 다시 확인해주세요.",
      };
    }

    case "RESULT": {
      const date = formatKoreanDate(
          goal.targetPassAnnouncementDate,
      );

      return {
        title: "합격자 발표일이에요",
        body:
            `${certificateName}${roundText} ` +
            `${examTypeName} 합격 결과를 ` +
            `오늘 확인할 수 있습니다.` +
            (date ? ` 발표일은 ${date}입니다.` : ""),
      };
    }

    default:
      throw new Error(
          `지원하지 않는 자격증 알림 타입: ${alertType}`,
      );
  }
}

async function createInAppNotification({
  uid,
  goalId,
  alertType,
  dateKey,
  message,
  goal,
}) {
  const notificationId =
      `${goalId}_${alertType}_${dateKey}`;

  const notificationRef = db
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .doc(notificationId);

  return db.runTransaction(
      async (transaction) => {
        const snapshot =
            await transaction.get(
                notificationRef,
            );

        if (snapshot.exists) {
          return false;
        }

        const expiresAt =
            admin.firestore.Timestamp.fromMillis(
                Date.now() +
                7 * 24 * 60 * 60 * 1000,
            );

        transaction.set(
            notificationRef,
            {
              notificationId,
              category: "CERTIFICATE",
              type: alertType,

              title: message.title,
              body: message.body,

              isRead: false,

              certificateId:
                  goal.certificateId || null,

              goalId,
              scheduleId:
                  goal.scheduleId || null,

              certificateName:
                  goal.certificateName || null,

              targetRound:
                  goal.targetRound || null,

              targetExamType:
                  goal.targetExamType || null,

              createdAt:
                  admin.firestore
                      .FieldValue
                      .serverTimestamp(),

              expiresAt,
            },
        );

        return true;
      },
  );
}

async function sendCertificateAlertsByType(
    alertType,
) {
  const config = ALERT_CONFIGS[alertType];

  if (!config) {
    throw new Error(
        `지원하지 않는 자격증 알림 타입: ${alertType}`,
    );
  }

  const {
    start,
    end,
    dateKey,
  } = getTodayRangeInSeoul();

  const goalsSnapshot = await db
      .collectionGroup("goals")
      .where(
          "goalStatus",
          "==",
          "ACTIVE",
      )
      .where(
          config.dateField,
          ">=",
          start,
      )
      .where(
          config.dateField,
          "<",
          end,
      )
      .get();

  if (goalsSnapshot.empty) {
    console.log(
        `[자격증 알림 대상 없음] type=${alertType}`,
    );

    return {
      alertType,
      targetCount: 0,
      sentCount: 0,
      skippedCount: 0,
      failedCount: 0,
    };
  }

  let sentCount = 0;
  let skippedCount = 0;
  let failedCount = 0;

  for (const goalDocument of
    goalsSnapshot.docs) {
    try {
      const goal = goalDocument.data();

      const userDocument =
          goalDocument.ref.parent.parent;

      const uid = userDocument?.id;

      if (!uid) {
        console.error(
            "[자격증 알림 실패] UID를 찾을 수 없음",
            goalDocument.ref.path,
        );

        failedCount++;
        continue;
      }

      const allowed = await canSend(
          uid,
          CERTIFICATE_CATEGORY_FIELD,
          config.settingField,
      );

      if (!allowed) {
        skippedCount++;
        continue;
      }

      const message =
          buildNotificationMessage(
              alertType,
              goal,
          );

      const created =
          await createInAppNotification({
            uid,
            goalId: goalDocument.id,
            alertType,
            dateKey,
            message,
            goal,
          });

      if (!created) {
        console.log(
            `[자격증 알림 중복 건너뜀] ` +
            `uid=${uid}, ` +
            `goalId=${goalDocument.id}, ` +
            `type=${alertType}`,
        );

        skippedCount++;
        continue;
      }

      await sendPush(
          uid,
          {
            title: message.title,
            body: message.body,

            data: {
              category: "CERTIFICATE",
              type: alertType,
              goalId: goalDocument.id,

              certificateId:
                  goal.certificateId || "",

              scheduleId:
                  goal.scheduleId || "",
            },
          },
      );

      sentCount++;
    } catch (error) {
      failedCount++;

      console.error(
          `[자격증 알림 처리 실패] ` +
          `goal=${goalDocument.ref.path}, ` +
          `type=${alertType}`,
          error,
      );
    }
  }

  const result = {
    alertType,
    targetCount: goalsSnapshot.size,
    sentCount,
    skippedCount,
    failedCount,
  };

  console.log(
      "[자격증 알림 처리 완료]",
      result,
  );

  return result;
}

async function sendMidnightCertificateAlerts() {
  const alertTypes = [
    "EXAM_D7",
    "EXAM_D1",
    "EXAM_DAY",
  ];

  const results = [];

  for (const alertType of alertTypes) {
    const result =
        await sendCertificateAlertsByType(
            alertType,
        );

    results.push(result);
  }

  return results;
}

async function sendMorningCertificateAlerts() {
  const alertTypes = [
    "APPLICATION_START",
    "APPLICATION_END_D1",
    "RESULT",
  ];

  const results = [];

  for (const alertType of alertTypes) {
    const result =
        await sendCertificateAlertsByType(
            alertType,
        );

    results.push(result);
  }

  return results;
}

const sendMidnightCertificateNotifications =
    onSchedule(
        {
          schedule: "every day 00:00",
          timeZone: "Asia/Seoul",
          timeoutSeconds: 540,
          memory: "512MiB",
        },
        async () => {
          await sendMidnightCertificateAlerts();
        },
    );

const sendMorningCertificateNotifications =
    onSchedule(
        {
          schedule: "every day 09:00",
          timeZone: "Asia/Seoul",
          timeoutSeconds: 540,
          memory: "512MiB",
        },
        async () => {
          await sendMorningCertificateAlerts();
        },
    );

module.exports = {
  sendMidnightCertificateNotifications,
  sendMorningCertificateNotifications,
};