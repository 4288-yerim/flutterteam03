const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

const db = admin.firestore();

const { saveInitialGoal } = require("../certification/certification");

exports.authKakao = onCall(async (request) => {
  const { accessToken, providerUserId, email, nickname } = request.data;

  if (!accessToken || !providerUserId) {
    throw new HttpsError("invalid-argument", "accessToken과 providerUserId가 필요합니다.");
  }

  let verifiedKakaoId;
  try {
    const kakaoResponse = await axios.get("https://kapi.kakao.com/v2/user/me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    verifiedKakaoId = kakaoResponse.data.id?.toString();
  } catch (err) {
    throw new HttpsError("unauthenticated", "카카오 토큰 검증 실패");
  }

  if (verifiedKakaoId !== providerUserId) {
    throw new HttpsError("unauthenticated", "토큰 검증 실패: 유저 정보 불일치");
  }

  const uid = `kakao_${verifiedKakaoId}`;

  let isNewUser = false;
  try {
    await admin.auth().getUser(uid);
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      isNewUser = true;
    } else {
      throw new HttpsError("internal", "계정 확인 중 오류가 발생했습니다.");
    }
  }

  if (!isNewUser) {
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "kakao",
      email: email || null,
      nickname: nickname || null,
    });
    return { firebaseCustomToken: customToken, isNewUser: false };
  }

  const signupToken = crypto.randomBytes(24).toString("hex");
  await db.collection("social_signup_tickets").doc(signupToken).set({
    provider: "kakao",
    uid,
    email: email || null,
    nickname: nickname || null,
    expiresAt: Date.now() + 15 * 60 * 1000,
    createdAt: Date.now(),
  });

  return { isNewUser: true, signupToken };
});

exports.completeSocialSignup = onCall(async (request) => {
  const { signupToken, agreements, goalCertificateId, nickname, bio } = request.data;

  if (!signupToken) throw new HttpsError("invalid-argument", "signupToken이 필요합니다.");
  if (!agreements?.terms || !agreements?.privacy || !agreements?.age) {
    throw new HttpsError("invalid-argument", "필수 약관에 동의해주세요.");
  }
  if (!nickname?.trim()) throw new HttpsError("invalid-argument", "닉네임을 입력해주세요.");

  const ticketRef = db.collection("social_signup_tickets").doc(signupToken);
  const snap = await ticketRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "인증 정보를 찾을 수 없습니다. 다시 로그인해주세요.");

  const ticket = snap.data();
  if (Date.now() > ticket.expiresAt) {
    await ticketRef.delete();
    throw new HttpsError("deadline-exceeded", "인증이 만료됐어요. 다시 로그인해주세요.");
  }

  const { uid, provider, email } = ticket;

  try {
    await admin.auth().getUser(uid);
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      await admin.auth().createUser({ uid, email: email || undefined });
    } else {
      throw new HttpsError("internal", "계정 생성 중 오류가 발생했습니다.");
    }
  }

  try {
    await db.collection("users").doc(uid).set({
      uid,
      email: email || null,
      loginProvider: provider.toUpperCase(),
      role: "USER",
      status: "ACTIVE",
      loginFailCount: 0,
      reportCount: 0,
      goalCertificateId: goalCertificateId || null,
      nickname: nickname.trim(),
      bio: bio || null,
      termsAgreed: !!agreements.terms,
      privacyAgreed: !!agreements.privacy,
      marketingAgreed: !!agreements.marketing,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await db.collection("users").doc(uid).collection("settings").doc("app").set({
      themeMode: "SYSTEM",
      pushEnabled: true,
      communityAlertEnabled: true,
      friendAlertEnabled: true,
      chatsAlertEnabled: true,
      marketingAlertEnabled: !!agreements.marketing,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      fontSizeMode: "MEDIUM",
      certificateAlertEnabled: true,
      applicationStartAlertEnabled: true,
      examD7AlertEnabled: true,
      examDayAlertEnabled: true,
      resultAlertEnabled: true,
      studyGroupAlertEnabled: true,
      studyNoticeAlertEnabled: true,
      studyJoinApprovalAlertEnabled: true,
      studyNewMemberAlertEnabled: true,
      studyChatsAlertEnabled: true,
      studyAlertEnabled: true,
      dailyStudyPlanAlertEnabled: true,
      studyStartTimeAlertEnabled: true,
      incompleteStudyAlertEnabled: true,
    }, { merge: true });
  } catch (err) {
    await admin.auth().deleteUser(uid).catch(() => {});
    throw new HttpsError("internal", "가입 처리 중 오류가 발생했습니다.");
  }

  if (goalCertificateId) {
    await saveInitialGoal(uid, goalCertificateId).catch((e) => {
      console.error("목표 자격증 저장 실패(completeSocialSignup): " + e.message);
    });
  }

  await ticketRef.delete();

  const customToken = await admin.auth().createCustomToken(uid, { provider, email: email || null });
  return { firebaseCustomToken: customToken, uid };
});

exports.authNaver = onCall(async (request) => {
  const { accessToken, providerUserId, email, nickname } = request.data;

  if (!accessToken || !providerUserId) {
    throw new HttpsError("invalid-argument", "accessToken과 providerUserId가 필요합니다.");
  }

  let verifiedNaverId;
  try {
    const naverResponse = await axios.get("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    verifiedNaverId = naverResponse.data?.response?.id;
  } catch (err) {
    throw new HttpsError("unauthenticated", "네이버 토큰 검증 실패");
  }

  if (verifiedNaverId !== providerUserId) {
    throw new HttpsError("unauthenticated", "토큰 검증 실패: 유저 정보 불일치");
  }

  const uid = `naver_${verifiedNaverId}`;

  let isNewUser = false;
  try {
    await admin.auth().getUser(uid);
  } catch (err) {
    if (err.code === "auth/user-not-found") {
      isNewUser = true;
    } else {
      throw new HttpsError("internal", "계정 확인 중 오류가 발생했습니다.");
    }
  }

  if (!isNewUser) {
    const customToken = await admin.auth().createCustomToken(uid, {
      provider: "naver",
      email: email || null,
      nickname: nickname || null,
    });
    return { firebaseCustomToken: customToken, isNewUser: false };
  }

  const signupToken = crypto.randomBytes(24).toString("hex");
  await db.collection("social_signup_tickets").doc(signupToken).set({
    provider: "naver",
    uid,
    email: email || null,
    nickname: nickname || null,
    expiresAt: Date.now() + 15 * 60 * 1000,
    createdAt: Date.now(),
  });

  return { isNewUser: true, signupToken };
});