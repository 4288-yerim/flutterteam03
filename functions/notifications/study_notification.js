"use strict";

const admin = require("firebase-admin");
const {
  onSchedule,
} = require("firebase-functions/v2/scheduler");

const {
  sendPush,
} = require("./notification_common");

const db = admin.firestore();

const STUDY_CATEGORY_FIELD = "studyAlertEnabled";
const DAILY_SETTING_FIELD = "dailyStudyPlanAlertEnabled";
const START_SETTING_FIELD = "studyStartTimeAlertEnabled";
const INCOMPLETE_SETTING_FIELD = "incompleteStudyAlertEnabled";

function getSeoulDateParts(date = new Date()) {
  const formatter = new Intl.DateTimeFormat(
      "en-CA",
      {
        timeZone: "Asia/Seoul",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      },
  );

  const values = {};

  for (const part of formatter.formatToParts(date)) {
    if (part.type !== "literal") {
      values[part.type] = part.value;
    }
  }

  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

function toDateKey(year, month, day) {
  return `${year}` +
      `${String(month).padStart(2, "0")}` +
      `${String(day).padStart(2, "0")}`;
}

function getTodayInSeoul() {
  const parts = getSeoulDateParts();
  const startMillis = Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      -9,
  );

  return {
    ...parts,
    dateKey: toDateKey(
        parts.year,
        parts.month,
        parts.day,
    ),
    start: admin.firestore.Timestamp.fromMillis(
        startMillis,
    ),
    end: admin.firestore.Timestamp.fromMillis(
        startMillis + 24 * 60 * 60 * 1000,
    ),
  };
}

function timestampToDate(value) {
  return value &&
    typeof value.toDate === "function" ?
    value.toDate() :
    null;
}

function timestampToSeoulDateKey(value) {
  const date = timestampToDate(value);

  if (!date) {
    return null;
  }

  const parts = getSeoulDateParts(date);

  return toDateKey(
      parts.year,
      parts.month,
      parts.day,
  );
}

function parseRecommendedStartDate(value, today) {
  if (typeof value !== "string") {
    return {
      year: today.year,
      month: today.month,
      day: today.day,
    };
  }

  const match = value.trim().match(
      /^(\d{4})-(\d{1,2})-(\d{1,2})/,
  );

  if (!match) {
    return {
      year: today.year,
      month: today.month,
      day: today.day,
    };
  }

  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
  };
}

function addDaysToDateParts(parts, days) {
  const date = new Date(Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day + days,
  ));

  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}

function getAiStepDateKey(
    step,
    index,
    recommendedStartDate,
) {
  const timestampFields = [
    step.planDate,
    step.planday,
    step.plannedAt,
  ];

  for (const value of timestampFields) {
    const dateKey = timestampToSeoulDateKey(value);

    if (dateKey) {
      return dateKey;
    }
  }

  const dayLabel = String(step.dayLabel || "");
  const match = dayLabel.match(/(\d{1,2})\/(\d{1,2})/);

  if (!match) {
    const fallback = addDaysToDateParts(
        recommendedStartDate,
        index,
    );

    return toDateKey(
        fallback.year,
        fallback.month,
        fallback.day,
    );
  }

  const month = Number(match[1]);
  const day = Number(match[2]);
  const year = month < recommendedStartDate.month ?
    recommendedStartDate.year + 1 :
    recommendedStartDate.year;

  return toDateKey(year, month, day);
}

function extractStudyItems(document, today) {
  const data = document.data() || {};
  const steps = Array.isArray(data.steps) ?
    data.steps :
    null;

  if (!steps) {
    return [{
      id: document.id,
      dateKey: timestampToSeoulDateKey(data.planday),
      title: String(data.plantitle || "학습 계획").trim(),
      isCompleted: data.status === true,
      startAt: timestampToDate(data.startplannedat),
      endAt: timestampToDate(data.endplannedat),
    }];
  }

  const recommendedStartDate =
      parseRecommendedStartDate(
          data.recommendedStudyStartDate,
          today,
      );

  return steps
      .filter((step) => step && typeof step === "object")
      .map((step, index) => ({
        id: `${document.id}_step_${index}`,
        dateKey: getAiStepDateKey(
            step,
            index,
            recommendedStartDate,
        ),
        title: String(step.title || "학습 계획").trim(),
        isCompleted: step.isCompleted === true,
        startAt: timestampToDate(
            step.startplannedat ||
            step.startPlannedAt,
        ),
        endAt: timestampToDate(
            step.endplannedat ||
            step.endPlannedAt,
        ),
      }));
}

async function getEnabledUsers(subTypeField) {
  const settingsSnapshot =
      await db.collectionGroup("settings").get();

  const users = [];

  for (const document of settingsSnapshot.docs) {
    if (document.id !== "app") {
      continue;
    }

    const settings = document.data() || {};
    const userDocument = document.ref.parent.parent;

    if (
      !userDocument ||
      settings.pushEnabled !== true ||
      settings[STUDY_CATEGORY_FIELD] !== true ||
      settings[subTypeField] !== true
    ) {
      continue;
    }

    users.push(userDocument.id);
  }

  return [...new Set(users)];
}

async function createStudyNotification({
  uid,
  notificationId,
  type,
  title,
  body,
  planDate,
  studyPlanId = null,
}) {
  const notificationRef = db
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .doc(notificationId);

  return db.runTransaction(async (transaction) => {
    const snapshot =
        await transaction.get(notificationRef);

    if (snapshot.exists) {
      return false;
    }

    transaction.set(notificationRef, {
      notificationId,
      category: "STUDY",
      type,
      title,
      body,
      isRead: false,
      refType: "STUDY_PLAN",
      planDate,
      studyPlanId,
      createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
      expiresAt:
          admin.firestore.Timestamp.fromMillis(
              Date.now() +
              7 * 24 * 60 * 60 * 1000,
          ),
    });

    return true;
  });
}

async function sendStudyNotification({
  uid,
  notificationId,
  type,
  title,
  body,
  planDate,
  studyPlanId = null,
}) {
  const created = await createStudyNotification({
    uid,
    notificationId,
    type,
    title,
    body,
    planDate,
    studyPlanId,
  });

  if (!created) {
    return false;
  }

  await sendPush(uid, {
    title,
    body,
    data: {
      category: "STUDY",
      type,
      refType: "STUDY_PLAN",
      planDate,
      studyPlanId: studyPlanId || "",
    },
  });

  return true;
}

async function getTodayItems(uid, today) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("studyPlans")
      .get();

  return snapshot.docs
      .flatMap(
          (document) =>
            extractStudyItems(document, today),
      )
      .filter(
          (item) => item.dateKey === today.dateKey,
      );
}

async function sendDailyStudyPlanAlerts() {
  const today = getTodayInSeoul();
  const users = await getEnabledUsers(
      DAILY_SETTING_FIELD,
  );

  for (const uid of users) {
    try {
      const items = await getTodayItems(uid, today);

      if (items.length === 0) {
        continue;
      }

      await sendStudyNotification({
        uid,
        notificationId:
            `study_daily_${today.dateKey}`,
        type: "DAILY_STUDY_PLAN",
        title: "오늘의 학습 계획",
        body:
            `오늘 예정된 학습 계획이 ` +
            `${items.length}개 있습니다.`,
        planDate: today.dateKey,
      });
    } catch (error) {
      console.error(
          `[오늘 학습 알림 실패] uid=${uid}`,
          error,
      );
    }
  }
}

async function sendIncompleteStudyAlerts() {
  const today = getTodayInSeoul();
  const users = await getEnabledUsers(
      INCOMPLETE_SETTING_FIELD,
  );

  for (const uid of users) {
    try {
      const items = await getTodayItems(uid, today);
      const incompleteCount = items.filter(
          (item) => !item.isCompleted,
      ).length;

      if (incompleteCount === 0) {
        continue;
      }

      await sendStudyNotification({
        uid,
        notificationId:
            `study_incomplete_${today.dateKey}`,
        type: "INCOMPLETE_STUDY_PLAN",
        title: "미완료 학습 계획",
        body:
            `오늘 미완료된 학습 계획이 ` +
            `${incompleteCount}개 있습니다.`,
        planDate: today.dateKey,
      });
    } catch (error) {
      console.error(
          `[미완료 학습 알림 실패] uid=${uid}`,
          error,
      );
    }
  }
}

function formatKoreanTime(date) {
  return new Intl.DateTimeFormat(
      "ko-KR",
      {
        timeZone: "Asia/Seoul",
        hour: "numeric",
        minute: "2-digit",
        hour12: true,
      },
  ).format(date);
}

async function sendStudyStartAlerts() {
  const now = Date.now();
  const targetStart =
      Math.floor((now + 10 * 60 * 1000) / 60000) *
      60000;
  const targetEnd = targetStart + 60000;

  const plansSnapshot = await db
      .collectionGroup("studyPlans")
      .where(
          "startplannedat",
          ">=",
          admin.firestore.Timestamp.fromMillis(
              targetStart,
          ),
      )
      .where(
          "startplannedat",
          "<",
          admin.firestore.Timestamp.fromMillis(
              targetEnd,
          ),
      )
      .get();

  const settingsCache = new Map();

  for (const document of plansSnapshot.docs) {
    try {
      const userDocument =
          document.ref.parent.parent;
      const uid = userDocument?.id;

      if (!uid) {
        continue;
      }

      if (!settingsCache.has(uid)) {
        const settingsSnapshot = await db
            .collection("users")
            .doc(uid)
            .collection("settings")
            .doc("app")
            .get();
        const settings =
            settingsSnapshot.data() || {};

        settingsCache.set(
            uid,
            settings.pushEnabled === true &&
            settings[STUDY_CATEGORY_FIELD] === true &&
            settings[START_SETTING_FIELD] === true,
        );
      }

      if (settingsCache.get(uid) !== true) {
        continue;
      }

      const data = document.data() || {};

      if (data.status === true) {
        continue;
      }

      const startAt =
          timestampToDate(data.startplannedat);
      const endAt =
          timestampToDate(data.endplannedat);

      if (!startAt) {
        continue;
      }

      const title =
          String(
              data.plantitle || "학습 계획",
          ).trim();
      const timeText = endAt ?
        `${formatKoreanTime(startAt)}부터 ` +
          `${formatKoreanTime(endAt)}까지` :
        `${formatKoreanTime(startAt)}부터`;
      const planDate =
          timestampToSeoulDateKey(
              data.planday ||
              data.startplannedat,
          );

      await sendStudyNotification({
        uid,
        notificationId:
            `study_start_${document.id}_` +
            `${startAt.getTime()}`,
        type: "STUDY_START",
        title: "학습 시작 10분 전이에요",
        body:
            `${title} 학습이 ${timeText} ` +
            `예정되어 있습니다. ` +
            `시작까지 10분 남았습니다.`,
        planDate,
        studyPlanId: document.id,
      });
    } catch (error) {
      console.error(
          `[학습 시작 알림 실패] ` +
          `plan=${document.ref.path}`,
          error,
      );
    }
  }
}

const sendDailyStudyPlanNotifications =
    onSchedule(
        {
          schedule: "every day 09:00",
          timeZone: "Asia/Seoul",
          timeoutSeconds: 540,
          memory: "512MiB",
        },
        sendDailyStudyPlanAlerts,
    );

const sendStudyStartNotifications =
    onSchedule(
        {
          schedule: "every 1 minutes",
          timeZone: "Asia/Seoul",
          timeoutSeconds: 540,
          memory: "512MiB",
        },
        sendStudyStartAlerts,
    );

const sendIncompleteStudyNotifications =
    onSchedule(
        {
          schedule: "every day 22:00",
          timeZone: "Asia/Seoul",
          timeoutSeconds: 540,
          memory: "512MiB",
        },
        sendIncompleteStudyAlerts,
    );

module.exports = {
  sendDailyStudyPlanNotifications,
  sendStudyStartNotifications,
  sendIncompleteStudyNotifications,
};
