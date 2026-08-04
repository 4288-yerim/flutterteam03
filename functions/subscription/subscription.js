const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");

const db = admin.firestore();

const PORTONE_API_KEY = defineSecret("PORTONE_API_KEY");
const PORTONE_API_SECRET = defineSecret("PORTONE_API_SECRET");

exports.verifySubscriptionPayment = onCall(
  { secrets: [PORTONE_API_KEY, PORTONE_API_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const customerUid = request.data?.customer_uid;
    const uid = request.auth.uid;

    if (!customerUid) {
      throw new HttpsError("invalid-argument", "customer_uid가 필요합니다.");
    }

    let accessToken;
    try {
      const tokenRes = await axios.post("https://api.iamport.kr/users/getToken", {
        imp_key: PORTONE_API_KEY.value(),
        imp_secret: PORTONE_API_SECRET.value(),
      });
      accessToken = tokenRes.data.response.access_token;
    } catch (err) {
      console.error("포트원 토큰 발급 실패: " + JSON.stringify(err.response?.data || { message: err.message }));
      throw new HttpsError("internal", "결제 서버 인증에 실패했습니다.");
    }

    const merchantUid = `sub_${Date.now()}_${uid}`;

    let payment;
    try {
      const chargeRes = await axios.post(
        "https://api.iamport.kr/subscribe/payments/again",
        {
          customer_uid: customerUid,
          merchant_uid: merchantUid,
          amount: 1000,
          name: "구름iT 구독 - 첫 달",
        },
        { headers: { Authorization: accessToken } }
      );
      payment = chargeRes.data.response;
    } catch (err) {
      console.error("첫 결제 실패: " + JSON.stringify(err.response?.data || { message: err.message }));
      throw new HttpsError("internal", "결제에 실패했습니다.");
    }

    if (!payment || payment.status !== "paid") {
      return { success: false, message: "결제 검증에 실패했습니다." };
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const paidAtMillis = payment.paid_at ? payment.paid_at * 1000 : Date.now();
    const expiresAtMillis = paidAtMillis + 30 * 24 * 60 * 60 * 1000;

    await db.collection("payments").doc(merchantUid).set({
      uid,
      impUid: payment.imp_uid,
      merchantUid,
      amount: payment.amount,
      status: "paid",
      paidAt: admin.firestore.Timestamp.fromMillis(paidAtMillis),
      planType: "MONTHLY",
    });

    await db.collection("users").doc(uid).collection("subscription").doc("current").set({
      planType: "MONTHLY",
      status: "ACTIVE",
      startedAt: admin.firestore.Timestamp.fromMillis(paidAtMillis),
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMillis),
      autoRenew: true,
      amount: payment.amount,
      paymentProvider: payment.pg_provider || "portone",
      latestPaymentId: merchantUid,
      billingKeyCustomerUid: customerUid,
      updatedAt: now,
      createdAt: now,
    }, { merge: true });

    return { success: true };
  }
);

exports.chargeRecurringSubscriptions = onSchedule(
  { schedule: "every day 03:00", timeZone: "Asia/Seoul", secrets: [PORTONE_API_KEY, PORTONE_API_SECRET] },
  async (event) => {
    const now = Date.now();
    const dueSnap = await db.collectionGroup("subscription")
      .where("status", "==", "ACTIVE")
      .where("autoRenew", "==", true)
      .where("expiresAt", "<=", admin.firestore.Timestamp.fromMillis(now))
      .get();

    if (dueSnap.empty) return;

    const tokenRes = await axios.post("https://api.iamport.kr/users/getToken", {
      imp_key: PORTONE_API_KEY.value(),
      imp_secret: PORTONE_API_SECRET.value(),
    });
    const accessToken = tokenRes.data.response.access_token;

    for (const doc of dueSnap.docs) {
      if (doc.id !== "current") continue;
      const sub = doc.data();
      const uid = doc.ref.parent.parent.id;
      const merchantUid = `sub_renew_${Date.now()}_${uid}`;

      try {
        const chargeRes = await axios.post(
          "https://api.iamport.kr/subscribe/payments/again",
          {
            customer_uid: sub.billingKeyCustomerUid,
            merchant_uid: merchantUid,
            amount: 2900,
            name: "구름iT 구독 갱신",
          },
          { headers: { Authorization: accessToken } }
        );

        const result = chargeRes.data.response;

        if (result.status === "paid") {
          const paidAtMillis = result.paid_at * 1000;
          const nextExpiresAt = paidAtMillis + 30 * 24 * 60 * 60 * 1000;

          await db.collection("payments").doc(merchantUid).set({
            uid,
            impUid: result.imp_uid,
            merchantUid,
            amount: result.amount,
            status: "paid",
            paidAt: admin.firestore.Timestamp.fromMillis(paidAtMillis),
            planType: "MONTHLY",
          });

          await doc.ref.update({
            startedAt: admin.firestore.Timestamp.fromMillis(paidAtMillis),
            expiresAt: admin.firestore.Timestamp.fromMillis(nextExpiresAt),
            latestPaymentId: merchantUid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else {
          await doc.ref.update({
            status: "EXPIRED",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } catch (err) {
        await doc.ref.update({
          status: "EXPIRED",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }
);

exports.cancelSubscription = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const uid = request.auth.uid;

  await db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("current")
    .update({
      autoRenew: false,
      status: "CANCELLED",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return { success: true };
});