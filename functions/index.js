const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// Firebase Console > Functions > Secrets 에 아래 3개를 등록해야 함
//   firebase functions:secrets:set EMAIL_USER
//   firebase functions:secrets:set EMAIL_PASS   (Gmail이면 앱 비밀번호)
//   firebase functions:secrets:set OTP_PEPPER   (임의의 긴 랜덤 문자열, 코드 해시용 salt)
const EMAIL_USER = defineSecret("EMAIL_USER");
const EMAIL_PASS = defineSecret("EMAIL_PASS");
const OTP_PEPPER = defineSecret("OTP_PEPPER");

const OTP_COLLECTION = "otp_verifications";
const OTP_TTL_MS = 5 * 60 * 1000; // 5분 (코드 자체의 유효시간)
const VERIFIED_TTL_MS = 15 * 60 * 1000; // 15분 (코드 인증 후 -> 약관동의 완료까지 허용 시간)
const RESEND_COOLDOWN_MS = 60 * 1000; // 60초
const MAX_ATTEMPTS = 5;

// 비밀번호 재설정 전용 OTP는 회원가입 OTP와 컬렉션을 분리한다.
// (같은 이메일로 로그인 상태에서 "재설정"과 "가입"이 동시에 진행되는 걸 서로 간섭하지 않게 하기 위함)
const PASSWORD_RESET_COLLECTION = "password_reset_otps";

function isValidEmail(email) {
  return typeof email === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function hashCode(code, pepper) {
  return crypto.createHash("sha256").update(`${code}:${pepper}`).digest("hex");
}

function generateCode() {
  // 000000 ~ 999999, 앞자리 0 유지
  return String(crypto.randomInt(0, 1000000)).padStart(6, "0");
}

function buildTransporter(user, pass) {
  return nodemailer.createTransport({
    service: "gmail", // 다른 SMTP 쓸 경우 host/port/secure로 교체
    auth: { user, pass },
  });
}

/**
 * 1단계: 이메일로 6자리 인증코드 발송
 * 요청: { email }
 * 주의: 여기서는 Firebase Auth 계정을 생성하지 않음. 코드와 만료시간만 Firestore에 임시 저장.
 * 비밀번호는 여기서 받지 않고, 최종 verifyOtp 단계에서 클라이언트가 다시 전달함
 * (Firestore에 평문 비밀번호를 저장하지 않기 위함)
 */
exports.sendOtp = onCall(
  { secrets: [EMAIL_USER, EMAIL_PASS, OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }

    // 이미 가입 완료된(=emailVerified) 계정이면 재가입 막기
    try {
      const existing = await admin.auth().getUserByEmail(email);
      if (existing) {
        throw new HttpsError("already-exists", "이미 가입된 이메일입니다.");
      }
    } catch (err) {
      if (err.code !== "auth/user-not-found") {
        // already-exists로 위에서 던진 HttpsError는 그대로 통과
        if (err instanceof HttpsError) throw err;
        throw new HttpsError("internal", "계정 확인 중 오류가 발생했습니다.");
      }
      // user-not-found면 정상 진행 (신규 가입 대상)
    }

    const docRef = db.collection(OTP_COLLECTION).doc(email);
    const snap = await docRef.get();

    // 재발송 쿨다운 체크
    if (snap.exists) {
      const data = snap.data();
      const lastSentAt = data.lastSentAt?.toMillis?.() ?? 0;
      if (Date.now() - lastSentAt < RESEND_COOLDOWN_MS) {
        const waitSec = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - lastSentAt)) / 1000);
        throw new HttpsError(
          "resource-exhausted",
          `잠시 후 다시 시도해주세요. (${waitSec}초 대기)`
        );
      }
    }

    const code = generateCode();
    const codeHash = hashCode(code, OTP_PEPPER.value());
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS);

    await docRef.set({
      codeHash,
      expiresAt,
      lastSentAt: now,
      attempts: 0,
      createdAt: now,
    });

    const transporter = buildTransporter(EMAIL_USER.value(), EMAIL_PASS.value());
    await transporter.sendMail({
      from: `"따IT" <${EMAIL_USER.value()}>`,
      to: email,
      subject: "[따IT] 이메일 인증코드가 도착했어요",
      html: `
        <div style="margin:0; padding:0; background-color:#F6F7F9; font-family: 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding: 40px 16px;">
            <tr>
              <td align="center">
                <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF; border-radius:20px; overflow:hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">
                  <tr>
                    <td style="background-color:#FFEFEF; padding: 36px 32px; text-align:center;">
                      <img src="https://firebasestorage.googleapis.com/v0/b/flutterteam3-724be.firebasestorage.app/o/textLogo.png?alt=media&token=3b531128-2b21-4d8c-9d01-3e71ddac3d3f" alt="따IT" width="120" style="display:block; margin:0 auto;" />
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 40px 36px 8px;">
                      <div style="font-size:20px; font-weight:800; color:#1A1A1A; margin-bottom:10px;">
                        이메일 인증코드를 보내드려요
                      </div>
                      <div style="font-size:14px; line-height:1.7; color:#6B7280;">
                        아래 6자리 코드를 앱에 입력하면 인증이 완료돼요.<br/>
                        코드는 <strong style="color:#1A1A1A;">5분간</strong> 유효하니 서둘러주세요!
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 24px 36px 8px;">
                      <div style="background-color:#FFF1F3; border:1px solid rgba(255,77,109,0.25); border-radius:16px; padding:22px; text-align:center;">
                        <div style="font-size:34px; font-weight:800; letter-spacing:10px; color:#FF4D6D;">
                          ${code}
                        </div>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 24px 36px 40px;">
                      <div style="font-size:12.5px; line-height:1.7; color:#9AA0AC;">
                        본인이 요청하지 않았다면 이 메일은 무시하셔도 괜찮아요.<br/>
                        인증코드는 절대 다른 사람과 공유하지 마세요.
                      </div>
                    </td>
                  </tr>
                </table>
                <div style="margin-top:20px; font-size:12px; color:#B0B4BB;">
                  © 따IT
                </div>
              </td>
            </tr>
          </table>
        </div>
      `,
    });

    return { success: true };
  }
);

exports.verifyOtp = onCall(
  { secrets: [OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();
    const code = (request.data?.code || "").trim();

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "인증코드는 6자리 숫자입니다.");
    }

    const docRef = db.collection(OTP_COLLECTION).doc(email);
    const snap = await docRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "인증코드를 먼저 요청해주세요.");
    }

    const data = snap.data();

    // 이미 코드 인증을 통과한 상태에서 재확인하는 경우, verificationToken이 안 만료됐으면 그대로 재사용
    if (data.verified && Date.now() <= (data.verificationExpiresAt?.toMillis?.() ?? 0)) {
      return { verified: true, verificationToken: data.verificationToken };
    }

    if (Date.now() > (data.expiresAt?.toMillis?.() ?? 0)) {
      await docRef.delete();
      throw new HttpsError("deadline-exceeded", "인증코드가 만료되었습니다. 다시 요청해주세요.");
    }

    if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
      await docRef.delete();
      throw new HttpsError("resource-exhausted", "시도 횟수를 초과했습니다. 다시 요청해주세요.");
    }

    const codeHash = hashCode(code, OTP_PEPPER.value());
    if (codeHash !== data.codeHash) {
      await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError("invalid-argument", "인증코드가 일치하지 않습니다.");
    }

    // 코드 일치 -> 인증 완료 표시만 해두고, 계정은 아직 만들지 않는다.
    const verificationToken = crypto.randomBytes(24).toString("hex");
    const verificationExpiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + VERIFIED_TTL_MS
    );

    await docRef.update({
      verified: true,
      verificationToken,
      verificationExpiresAt,
    });

    return { verified: true, verificationToken };
  }
);

exports.completeSignup = onCall(
  {},
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();
    const password = request.data?.password || "";
    const verificationToken = request.data?.verificationToken || "";
    const agreements = request.data?.agreements || {};
    const goalCertificateId = request.data?.goalCertificateId || null;

    const nickname = (request.data?.nickname || "").trim();
    const bio = request.data?.bio || null;

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }
    if (typeof password !== "string" || password.length < 6) {
      throw new HttpsError("invalid-argument", "비밀번호는 6자 이상이어야 합니다.");
    }
    if (!verificationToken) {
      throw new HttpsError("invalid-argument", "이메일 인증을 먼저 완료해주세요.");
    }
   if (!agreements.terms || !agreements.privacy || !agreements.age) {
     throw new HttpsError("invalid-argument", "필수 약관에 동의해주세요.");
   }
   if (!nickname) {
     throw new HttpsError("invalid-argument", "닉네임을 입력해주세요.");
   }

    const docRef = db.collection(OTP_COLLECTION).doc(email);
    const snap = await docRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "이메일 인증을 먼저 완료해주세요.");
    }

    const data = snap.data();

    if (!data.verified || data.verificationToken !== verificationToken) {
      throw new HttpsError("permission-denied", "이메일 인증 정보가 올바르지 않습니다.");
    }

    if (Date.now() > (data.verificationExpiresAt?.toMillis?.() ?? 0)) {
      await docRef.delete();
      throw new HttpsError(
        "deadline-exceeded",
        "인증이 만료됐어요. 이메일 인증부터 다시 진행해주세요."
      );
    }

    // 이 시점에 비로소 Firebase Auth 계정 생성
    let userRecord;
    try {
      userRecord = await admin.auth().createUser({
        email,
        password,
        emailVerified: true,
      });
    } catch (err) {
      if (err.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "이미 가입된 이메일입니다.");
      }
      throw new HttpsError("internal", "계정 생성 중 오류가 발생했습니다.");
    }

    // Firestore 유저 문서까지 같은 호출 안에서 생성 (약관동의와 계정 생성을 사실상 하나의 단위로 묶음)
    try {
     await db.collection("users").doc(userRecord.uid).set({
       uid: userRecord.uid,
       email: userRecord.email,
       loginProvider: "PASSWORD",
       role: "USER",
       status: "ACTIVE",
       loginFailCount: 0,
       reportCount: 0,
       termsAgreed: !!agreements.terms,
       privacyAgreed: !!agreements.privacy,
       marketingAgreed: !!agreements.marketing,
       goalCertificateId: goalCertificateId,
       nickname: nickname,
       bio: bio,
       createdAt: admin.firestore.FieldValue.serverTimestamp(),
       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
     });

     await db.collection("users").doc(userRecord.uid).collection("settings").doc("app").set({
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
     });
    } catch (err) {
      // Firestore 문서 생성 실패 -> 방금 만든 Auth 계정 롤백
      await admin.auth().deleteUser(userRecord.uid).catch(() => {});
      throw new HttpsError("internal", "가입 처리 중 오류가 발생했습니다. 다시 시도해주세요.");
    }

    await docRef.delete();

    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    return { customToken, uid: userRecord.uid };
  }
);

exports.sendPasswordResetOtp = onCall(
  { secrets: [EMAIL_USER, EMAIL_PASS, OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }

    // 가입 이력이 없으면 재설정 코드를 보낼 이유가 없다.
    try {
      await admin.auth().getUserByEmail(email);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        throw new HttpsError("not-found", "가입 이력이 없는 이메일입니다.");
      }
      throw new HttpsError("internal", "계정 확인 중 오류가 발생했습니다.");
    }

    const docRef = db.collection(PASSWORD_RESET_COLLECTION).doc(email);
    const snap = await docRef.get();

    // 재발송 쿨다운 체크 (sendOtp와 동일한 정책)
    if (snap.exists) {
      const data = snap.data();
      const lastSentAt = data.lastSentAt?.toMillis?.() ?? 0;
      if (Date.now() - lastSentAt < RESEND_COOLDOWN_MS) {
        const waitSec = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - lastSentAt)) / 1000);
        throw new HttpsError(
          "resource-exhausted",
          `잠시 후 다시 시도해주세요. (${waitSec}초 대기)`
        );
      }
    }

    const code = generateCode();
    const codeHash = hashCode(code, OTP_PEPPER.value());
    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + OTP_TTL_MS);

    await docRef.set({
      codeHash,
      expiresAt,
      lastSentAt: now,
      attempts: 0,
      createdAt: now,
    });

    const transporter = buildTransporter(EMAIL_USER.value(), EMAIL_PASS.value());
    await transporter.sendMail({
      from: `"따IT" <${EMAIL_USER.value()}>`,
      to: email,
      subject: "[따IT] 비밀번호 재설정 인증코드가 도착했어요",
      html: `
        <div style="margin:0; padding:0; background-color:#F6F7F9; font-family: 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding: 40px 16px;">
            <tr>
              <td align="center">
                <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="background-color:#FFFFFF; border-radius:20px; overflow:hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.06);">
                  <tr>
                    <td style="background-color:#FFEFEF; padding: 36px 32px; text-align:center;">
                      <img src="https://firebasestorage.googleapis.com/v0/b/flutterteam3-724be.firebasestorage.app/o/textLogo.png?alt=media&token=3b531128-2b21-4d8c-9d01-3e71ddac3d3f" alt="따IT" width="120" style="display:block; margin:0 auto;" />
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 40px 36px 8px;">
                      <div style="font-size:20px; font-weight:800; color:#1A1A1A; margin-bottom:10px;">
                        비밀번호 재설정 인증코드예요
                      </div>
                      <div style="font-size:14px; line-height:1.7; color:#6B7280;">
                        아래 6자리 코드를 앱에 입력하면 새 비밀번호를 설정할 수 있어요.<br/>
                        코드는 <strong style="color:#1A1A1A;">5분간</strong> 유효하니 서둘러주세요!
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 24px 36px 8px;">
                      <div style="background-color:#FFF1F3; border:1px solid rgba(255,77,109,0.25); border-radius:16px; padding:22px; text-align:center;">
                        <div style="font-size:34px; font-weight:800; letter-spacing:10px; color:#FF4D6D;">
                          ${code}
                        </div>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding: 24px 36px 40px;">
                      <div style="font-size:12.5px; line-height:1.7; color:#9AA0AC;">
                        본인이 요청하지 않았다면 이 메일은 무시하셔도 괜찮아요.<br/>
                        인증코드는 절대 다른 사람과 공유하지 마세요.
                      </div>
                    </td>
                  </tr>
                </table>
                <div style="margin-top:20px; font-size:12px; color:#B0B4BB;">
                  © 따IT
                </div>
              </td>
            </tr>
          </table>
        </div>
      `,
    });

    return { success: true };
  }
);

/**
 * 비밀번호 재설정 2단계: 인증코드 검증 + 새 비밀번호로 즉시 변경.
 * 회원가입 플로우와 다르게 별도의 verificationToken 단계 없이 한 번의 호출로 끝낸다
 * (재설정은 그 사이에 추가로 거쳐야 할 화면이 없기 때문).
 * 요청: { email, code, newPassword }
 */
exports.resetPassword = onCall(
  { secrets: [OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();
    const code = (request.data?.code || "").trim();
    const newPassword = request.data?.newPassword || "";

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "인증코드는 6자리 숫자입니다.");
    }
    if (typeof newPassword !== "string" || newPassword.length < 6) {
      throw new HttpsError("invalid-argument", "비밀번호는 6자 이상이어야 합니다.");
    }

    const docRef = db.collection(PASSWORD_RESET_COLLECTION).doc(email);
    const snap = await docRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "인증코드를 먼저 요청해주세요.");
    }

    const data = snap.data();

    if (Date.now() > (data.expiresAt?.toMillis?.() ?? 0)) {
      await docRef.delete();
      throw new HttpsError("deadline-exceeded", "인증코드가 만료되었습니다. 다시 요청해주세요.");
    }

    if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
      await docRef.delete();
      throw new HttpsError("resource-exhausted", "시도 횟수를 초과했습니다. 다시 요청해주세요.");
    }

    const codeHash = hashCode(code, OTP_PEPPER.value());
    if (codeHash !== data.codeHash) {
      await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      throw new HttpsError("invalid-argument", "인증코드가 일치하지 않습니다.");
    }

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (err) {
      throw new HttpsError("not-found", "가입 이력이 없는 이메일입니다.");
    }

    try {
      await admin.auth().updateUser(userRecord.uid, { password: newPassword });
    } catch (err) {
      throw new HttpsError("internal", "비밀번호 변경 중 오류가 발생했습니다.");
    }

    await docRef.delete();

    return { success: true };
  }
);
// functions/index.js (기존 파일에 추가)

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

const { onSchedule } = require("firebase-functions/v2/scheduler");

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
      if (doc.id !== "current") continue; // subscription/current 문서만 처리
      const sub = doc.data();
      const uid = doc.ref.parent.parent.id; // users/{uid}/subscription/current -> uid 추출
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

const QNET_SERVICE_KEY = defineSecret("QNET_SERVICE_KEY");

exports.getCertificateSchedule = onCall(
  { secrets: [QNET_SERVICE_KEY] },
  async (request) => {
    const year = request.data?.year || new Date().getFullYear();
    const cacheDoc = db.collection("certSchedule").doc(`${year}`);

    const cached = await cacheDoc.get();
    if (cached.exists) {
      const cachedAt = cached.data().cachedAt?.toDate();
      if (cachedAt && (Date.now() - cachedAt.getTime()) < 24 * 60 * 60 * 1000) {
        return { success: true, items: cached.data().items };
      }
    }

    try {
      const response = await axios.get(
        "https://apis.data.go.kr/B490007/qualExamSchd/getQualExamSchdList",
        {
          params: {
            serviceKey: QNET_SERVICE_KEY.value(),
            numOfRows: 200,
            pageNo: 1,
            dataFormat: "json",
            implYy: year,
            qualgbCd: "T", // 국가기술자격만
          },
        }
      );

      const items = response.data?.response?.body?.items?.item || [];

      await cacheDoc.set({
        items,
        cachedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, items };
    } catch (e) {
      console.error("자격시험 일정 조회 실패: " + JSON.stringify(e.response?.data || { message: e.message }));
      return { success: false, message: e.message };
    }
  }
);

const { GoogleGenAI } = require("@google/genai");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

exports.suggestCertificatesForJob = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const job = (request.data?.job || "").trim();
    if (!job) {
      throw new HttpsError("invalid-argument", "직무를 입력해주세요.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `"${job}"이(가) 실제 직무/직업명이 아니거나 자격증 추천이 불가능한 값이면 빈 배열 []만 반환해.
    실제 직무라면, 이 직무를 목표로 하는 사람에게 도움이 되는 한국 자격증을 최대 6개까지 추천해줘.
    국가기술자격, 국가전문자격, 국가공인 민간자격을 우선 고려해.

    배열의 순서는 반드시 "실제로 준비하고 취득해야 하는 순서"를 따라야 해:
    - 같은 분야에 등급이 여러 개 있는 국가기술자격은 낮은 등급부터 순서대로 나열해 (기능사 → 산업기사 → 기사 → 기능장 → 기술사).
      예: "정보처리산업기사"는 "정보처리기사"보다 반드시 먼저 나와야 해.
    - 등급 체계가 없는 자격증(어학시험, IT 인증 등)은 난이도나 우선순위가 낮은 것부터 배치해.
    - 서로 다른 분야의 자격증 사이에서는 직무에 더 핵심적이고 활용도가 높은 것을 먼저 배치해.

    아래 JSON 배열 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
    [{"name": "자격증 이름", "description": "한 문장 설명"}]`;

    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      const jsonMatch = text.match(/\[[\s\S]*\]/);
      const certs = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      return { success: true, certificates: certs };
    } catch (e) {
      console.error("자격증 추천 실패: " + e.message);
      return { success: false, message: "추천을 생성하지 못했어요." };
    }
  }
);

exports.incrementJobPopularity = onCall(async (request) => {
  const job = (request.data?.job || "").trim().toLowerCase().replace(/\s+/g, "");
  if (!job || job.length > 30) {
    throw new HttpsError("invalid-argument", "잘못된 직무명입니다.");
  }

  const ref = admin.firestore().collection("job_popularity").doc(job);
  await ref.set(
    {
      displayName: request.data.job.trim(), // 화면 표시용 원본
      count: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  return { success: true };
});

exports.getPopularJobs = onCall(async () => {
  const snap = await admin.firestore()
    .collection("job_popularity")
    .orderBy("count", "desc")
    .limit(5)
    .get();
  return { jobs: snap.docs.map(d => ({ name: d.data().displayName, count: d.data().count })) };
});

exports.validateCertificateName = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) return { valid: false };

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `"${name}"이(가) 실제로 존재하는 자격증, 수료증, 어학/IT 인증시험 이름인지 판단해줘.
국가기술자격, 국가전문자격, 민간자격, 어학시험(TOEIC 등), IT 인증(정보처리기사 등) 모두 포함해서 폭넓게 판단해.
아래 JSON 형식으로만 응답하고 다른 텍스트는 포함하지 마:
{"valid": true} 또는 {"valid": false}`;

    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);
      return { valid: parsed.valid === true };
    } catch (e) {
      console.error("자격증 검증 실패: " + e.message);
      return { valid: true }; // 검증 실패 시엔 막지 않고 통과시킴
    }
  }
);

exports.getCertificateStructure = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `"${name}"이(가) 실제 존재하는 한국의 자격증/인증시험이 맞는지 먼저 판단해.
    존재하지 않거나 자격증이 아니면 {"valid": false}만 반환해.

    실제 자격증이라면, 이 시험의 구조를 분석해서 아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true,
      "hasWritten": true 또는 false,
      "hasPractical": true 또는 false,
      "isIntegrated": true 또는 false,
      "writtenSubjects": ["과목1", "과목2"],
      "practicalSubjects": ["과목1"],
      "integratedSubjects": []
    }

    규칙:
    - 필기/실기 구분이 있는 시험은 isIntegrated를 false로 하고, hasWritten/hasPractical과 writtenSubjects/practicalSubjects를 채워.
    - 필기/실기 구분 없이 하나로 치러지는 시험(어학시험, 한국사능력검정시험 등)은 isIntegrated를 true로 하고 integratedSubjects만 채우고 hasWritten/hasPractical은 false로 해.
    - 과목이 명확히 나뉘지 않는 시험은 해당 배열에 전체 시험명을 하나의 항목으로 넣어.`;

    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      if (parsed.valid !== true) {
        return { success: false, message: "실제 존재하는 자격증을 찾지 못했어요." };
      }

      return {
        success: true,
        structure: {
          name,
          hasWritten: !!parsed.hasWritten,
          hasPractical: !!parsed.hasPractical,
          isIntegrated: !!parsed.isIntegrated,
          writtenSubjects: parsed.writtenSubjects || [],
          practicalSubjects: parsed.practicalSubjects || [],
          integratedSubjects: parsed.integratedSubjects || [],
        },
      };
    } catch (e) {
      console.error("자격증 구조 분석 실패: " + e.message);
      return { success: false, message: "자격증 정보를 불러오지 못했어요." };
    }
  }
);

exports.generateQuestion = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const { certificationName, examType, subject, generationType } = request.data || {};

    if (!certificationName || !examType) {
      throw new HttpsError("invalid-argument", "필수 정보가 누락되었습니다.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const subjectText = subject ? `"${subject}" 과목의 ` : "";
    const prompt = `너는 "${certificationName}" 자격증 ${examType} 시험 문제를 출제하는 전문가야.
    ${subjectText}실제 시험 난이도와 형식에 맞는 문제 1개를 만들어줘.

    아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "question": "문제 내용",
      "options": ["보기1", "보기2", "보기3", "보기4"],
      "answer": "정답 (options 중 하나와 정확히 일치)",
      "explanation": "정답에 대한 해설"
    }

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 단답형/서술형에 가까운 실기 문제면 options는 빈 배열로 하고 answer에 정답을 직접 써.
    - 한국어로 작성해.`;

    try {
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      return {
        success: true,
        question: {
          question: parsed.question || "",
          options: parsed.options || [],
          answer: parsed.answer || "",
          explanation: parsed.explanation || "",
        },
      };
    } catch (e) {
      console.error("문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.extractDocumentText = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const { documentUrl } = request.data || {};

    if (!documentUrl) {
      throw new HttpsError("invalid-argument", "문서 URL이 없습니다.");
    }

    try {
      const fileResponse = await axios.get(documentUrl, {
        responseType: "arraybuffer",
      });
      const base64Pdf = Buffer.from(fileResponse.data).toString("base64");

      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
      const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

      const prompt = `첨부된 문서의 내용을 문제 출제에 쓸 수 있도록 핵심 개념, 용어, 수치, 정의를 빠짐없이 정리해줘.
      원문의 문장을 요약하지 말고, 출제 가능한 세부 정보를 최대한 많이 남겨줘.
      다른 설명 없이 정리된 텍스트만 출력해.`;

      const result = await model.generateContent([
        { inlineData: { mimeType: "application/pdf", data: base64Pdf } },
        { text: prompt },
      ]);

      const extractedText = result.response.text();

      if (!extractedText || extractedText.trim().length < 30) {
        return { success: false, message: "문서에서 내용을 추출하지 못했어요." };
      }

      return { success: true, extractedText };
    } catch (e) {
      console.error("문서 텍스트 추출 실패: " + (e.response?.data ? JSON.stringify(e.response.data) : e.message));
      return { success: false, message: "문서를 분석하지 못했어요." };
    }
  }
);

exports.generateQuestionsFromText = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    const { extractedText, count } = request.data || {};
    const questionCount = count || 20;

    if (!extractedText) {
      throw new HttpsError("invalid-argument", "추출된 텍스트가 없습니다.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `아래는 학습 자료에서 정리한 내용이야:
    ---
    ${extractedText}
    ---

    이 내용을 바탕으로 서로 겹치지 않는 문제 ${questionCount}개를 만들어줘.
    자료에 실제로 나온 개념·용어·수치를 기반으로 다양한 부분에서 골고루 출제해야 해.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 자료 내용만으로 답할 수 있는 문제여야 해.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${questionCount}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await model.generateContent(prompt);
      let text = result.response.text();
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("문서 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.generateQuestionsFromWrongAnswers = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = request.auth.uid;
    const count = request.data?.count || 20;
    const certificationName = request.data?.certificationName || null;

    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("wrong_answers")
      .orderBy("createdAt", "desc")
      .limit(50)
      .get();

    let docs = snap.docs.map((d) => d.data());

    // 특정 자격증으로 필터링 가능하면 필터링, 결과가 없으면 전체로 폴백
    if (certificationName) {
      const filtered = docs.filter((d) => d.certificationName === certificationName);
      if (filtered.length > 0) docs = filtered;
    }

    if (docs.length === 0) {
      return { success: false, message: "아직 오답 기록이 없어요. 먼저 문제를 풀어주세요." };
    }

    const summary = docs
      .slice(0, 30)
      .map((d, i) =>
        `${i + 1}. 문제: ${d.question}\n   정답: ${d.correctAnswer}\n   내가 고른 답: ${d.userAnswer}\n   해설: ${d.explanation || ""}`
      )
      .join("\n\n");

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `아래는 학습자가 과거에 틀렸던 문제들이야:
    ---
    ${summary}
    ---

    이 문제들이 다루는 개념과 비슷하지만, 완전히 새로운 문제 ${count}개를 만들어줘.
    같은 개념을 다른 방식으로 물어보거나, 학습자가 헷갈려했던 지점을 다시 확인할 수 있는 문제로 구성해.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${count}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await model.generateContent(prompt);
      let text = result.response.text();
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("오답 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);

exports.generateQuestionsForCertification = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    const { certificationName, examType, subject, count } = request.data || {};
    const questionCount = count || 20;

    if (!certificationName || !examType) {
      throw new HttpsError("invalid-argument", "필수 정보가 누락되었습니다.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const subjectText = subject ? `"${subject}" 과목의 ` : "";
    const prompt = `너는 "${certificationName}" 자격증 ${examType} 시험 문제를 출제하는 전문가야.
    ${subjectText}실제 시험 난이도와 형식에 맞는, 서로 겹치지 않는 문제 ${questionCount}개를 만들어줘.

    아래 JSON 배열 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    [
      {
        "question": "문제 내용",
        "options": ["보기1", "보기2", "보기3", "보기4"],
        "answer": "정답 (options 중 하나와 정확히 일치)",
        "explanation": "정답에 대한 해설"
      }
    ]

    규칙:
    - 객관식이면 보기 4개 중 하나가 정답이어야 해.
    - 단답형/서술형에 가까운 실기 문제면 options는 빈 배열로 하고 answer에 정답을 직접 써.
    - 문제끼리 내용이 겹치지 않아야 해.
    - 정확히 ${questionCount}개를 만들어야 해.
    - 한국어로 작성해.`;

    const tryGenerate = async () => {
      const result = await model.generateContent(prompt);
      let text = result.response.text();
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\[[\s\S]*\]/);
      if (!jsonMatch) {
        throw new Error("JSON 배열 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    try {
      let parsed;
      try {
        parsed = await tryGenerate();
      } catch (firstError) {
        console.error("1차 파싱 실패, 재시도: " + firstError.message);
        parsed = await tryGenerate();
      }

      const questions = (Array.isArray(parsed) ? parsed : []).map((q) => ({
        question: q.question || "",
        options: q.options || [],
        answer: q.answer || "",
        explanation: q.explanation || "",
      }));

      if (questions.length === 0) {
        return { success: false, message: "문제를 생성하지 못했어요." };
      }

      return { success: true, questions };
    } catch (e) {
      console.error("자격증 기반 문제 생성 실패: " + e.message);
      return { success: false, message: "문제를 생성하지 못했어요." };
    }
  }
);
exports.summarizeMaterial = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 180 },
  async (request) => {
    const fileUrls = request.data?.fileUrls;
    const selectedCertificate = (request.data?.selectedCertificate || "").trim();
    const forceSummary = !!request.data?.forceSummary;

    if (!Array.isArray(fileUrls) || fileUrls.length === 0) {
      throw new HttpsError("invalid-argument", "요약할 파일 URL이 없습니다.");
    }
    if (!selectedCertificate) {
      throw new HttpsError("invalid-argument", "선택한 자격증 정보가 없습니다.");
    }
    if (fileUrls.length > 10) {
      throw new HttpsError("invalid-argument", "한 번에 요약할 수 있는 파일 개수를 초과했습니다.");
    }

    // 1) 파일들을 병렬로 다운로드 -> base64 변환 (Gemini inlineData 형식)
    let fileParts;
    try {
      fileParts = await Promise.all(
        fileUrls.map(async (url) => {
          const res = await axios.get(url, { responseType: "arraybuffer" });
          const mimeType = res.headers["content-type"] || "application/pdf";
          const base64 = Buffer.from(res.data).toString("base64");
          return { inlineData: { mimeType, data: base64 } };
        })
      );
    } catch (e) {
      console.error("요약용 파일 다운로드 실패: " + e.message);
      throw new HttpsError("internal", "업로드한 파일을 불러오지 못했습니다.");
    }

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const matchInstruction = forceSummary
      ? `certificate_match는 항상 true로 응답해. (사용자가 이미 자료를 확인했고 계속 진행하기로 선택했음)`
      : `가장 먼저, 첨부된 자료의 실제 내용이 "${selectedCertificate}" 자격증과 실질적으로 관련이 있는지 판단해.
      - 관련이 있으면 certificate_match를 true로, detected_certificate는 "${selectedCertificate}"와 동일하게, mismatch_reason은 빈 문자열로 응답해.
      - 관련이 없어 보이면 certificate_match를 false로, detected_certificate에는 자료가 실제로 어떤 자격증/분야에 가까운지 적고,
        mismatch_reason에는 왜 그렇게 판단했는지 1~2문장으로 간단히 적어.`;

    const prompt = `너는 자격증 시험 준비를 돕는 학습 자료 요약 도우미야.
사용자가 선택한 자격증은 "${selectedCertificate}"이고, 총 ${fileParts.length}개의 자료 파일이 첨부되어 있어.

수행할 작업:
1. ${matchInstruction}
2. 자료의 핵심 개념, 중요 용어, 정의, 수치를 놓치지 않고 시험 대비에 도움이 되도록 구조적으로 요약해.
   - 소제목과 목록(줄바꿈)을 활용해서 읽기 쉽게 정리해.
   - 자료에 없는 내용을 지어내지 마.

아래 JSON 형식으로만 응답하고, 다른 텍스트나 코드블록 표시(\`\`\`)는 절대 포함하지 마:
{
  "certificate_match": true 또는 false,
  "detected_certificate": "자료가 실제로 관련있어 보이는 자격증/분야 이름",
  "mismatch_reason": "불일치 판단 이유 (일치하면 빈 문자열)",
  "summary": "정리된 요약 내용 전체 (문자열)",
  "original_length": 자료 원문 전체 글자 수 추정치 (숫자)
}`;

    const tryGenerate = async () => {
      const result = await model.generateContent([...fileParts, { text: prompt }]);
      let text = result.response.text();
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        throw new Error("JSON 형식을 찾지 못했습니다: " + text.slice(0, 200));
      }
      return JSON.parse(jsonMatch[0]);
    };

    let parsed;
    try {
      parsed = await tryGenerate();
    } catch (firstError) {
      console.error("요약 1차 파싱 실패, 재시도: " + firstError.message);
      try {
        parsed = await tryGenerate();
      } catch (secondError) {
        console.error("요약 생성 실패: " + secondError.message);
        throw new HttpsError("internal", "요약을 생성하지 못했습니다. 다시 시도해주세요.");
      }
    }

    const summary = (parsed.summary || "").trim();

    // certificate_match가 false인 경우, 클라이언트는 확인 다이얼로그만 띄우고
    // summary는 아직 안 봐도 되지만, 혹시 비어 있어도 여기서 에러 내지 않는다.
    const certificateMatch = forceSummary ? true : parsed.certificate_match !== false;

    if (certificateMatch && !summary) {
      throw new HttpsError("internal", "서버에서 빈 요약 결과를 반환했습니다.");
    }

    const originalLength = Number.isFinite(Number(parsed.original_length))
      ? Number(parsed.original_length)
      : 0;

    return {
      certificate_match: certificateMatch,
      detected_certificate: parsed.detected_certificate || "",
      mismatch_reason: parsed.mismatch_reason || "",
      summary,
      original_length: originalLength,
      summary_length: summary.length,
      file_count: fileParts.length,
    };
  }
);

exports.estimateCertificateInfo = onCall(
  { secrets: [GEMINI_API_KEY] },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
    const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

    const prompt = `오늘 날짜는 ${todayStr}이야.
    "${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 판단하고,
    이 시험의 "오늘 이후로 가장 가까운 다가오는 회차"의 접수 기간과 시험일을 추정해줘.

    아래 JSON 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true 또는 false,
      "level": "국가기술자격/국가전문자격/민간자격/어학시험 등 자격 구분 (모르면 null)",
      "registrationPeriod": "YYYY. MM. DD ~ YYYY. MM. DD 형식의 가장 가까운 다가오는 접수 기간 (모르면 null)",
      "examDate": "YYYY. MM. DD 형식의 가장 가까운 다가오는 시험일 (모르면 null)"
    }

   규칙:
       - valid가 false면 나머지 필드는 모두 null로 해.
       - registrationPeriod의 종료일(접수 마감일)은 반드시 오늘(${todayStr}) 이후여야 해. 접수가 이미 마감된 회차는 절대 반환하지 마.
       - examDate는 registrationPeriod 다음 회차의 시험일이면 되고, 오늘 이후인지는 별도로 신경 쓰지 않아도 돼 (접수기간만 안 지나면 됨).
       - 정확한 공식 일정을 모르더라도, 이 자격증의 일반적인 연간 시행 회차 패턴(예: 정보처리기사는 보통 1월/4월/7월경 접수, 5~6월/8월/10~11월경 시험 등)을 근거로 오늘 기준 다음 회차를 계산해서 구체적인 날짜로 답해.
       - "보통 연 O회 시행" 같은 설명 문장이 아니라, 반드시 위 예시처럼 실제 날짜 형식으로 답해.
       - 그래도 도저히 패턴을 알 수 없는 자격증이면 null로 응답해 (이 경우 앱에서 "주관사 확인 필요" 안내를 대신 보여줌).`;

    try {
      const result = await model.generateContent(prompt);
      let text = result.response.text();
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();

      const jsonMatch = text.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

      if (parsed.valid !== true) {
        return { success: false, message: "자격증 정보를 추정하지 못했어요." };
      }

      return {
        success: true,
        info: {
          level: parsed.level || null,
          registrationPeriod: parsed.registrationPeriod || null,
          examDate: parsed.examDate || null,
        },
      };
    } catch (e) {
      console.error("자격증 정보 추정 실패: " + e.message);
      return { success: false, message: "자격증 정보를 추정하지 못했어요." };
    }
  }
);

exports.estimateCertificateDetailInfo = onCall(
   { secrets: [GEMINI_API_KEY] },
   async (request) => {
     const name = (request.data?.name || "").trim();
     if (!name) {
       throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
     }

     const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
     const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });

     const prompt = `"${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 판단하고,
     이 시험의 응시료, 출제 경향, 취득 방법 정보를 알려줘.

     아래 JSON 형식으로만 응답하고 다른 텍스트는 절대 포함하지 마:
     {
       "valid": true 또는 false,
       "examFee": {
         "firstLabel": "1차 또는 필기 등 (없으면 null)",
         "firstAmount": 숫자 (원 단위, 모르면 null),
         "secondLabel": "2차 또는 실기 등 (없으면 null)",
         "secondAmount": 숫자 (원 단위, 모르면 null)
       },
       "examTrends": {
         "header": "예: 실기시험 출제 경향 (없으면 null)",
         "topics": ["세부 출제 항목1", "세부 출제 항목2"]
       },
       "howToObtain": {
         "agency": "시행처 (모르면 null)",
         "department": "관련 학과 (없으면 null)",
         "writtenSubjects": ["필기 과목1", "필기 과목2"],
         "practicalSubjects": "실기 과목/방식 설명 (없으면 null)",
         "passCriteria": "합격 기준 (모르면 null)"
       }
     }

     규칙:
     - valid가 false면 다른 필드는 모두 null 또는 빈 값으로 해.
     - 필기/실기 구분이 없는 시험(어학시험 등)은 writtenSubjects에 전체 과목/영역을 넣고 practicalSubjects는 null로 해.
     - examTrends.topics는 가능하면 2개 이상 항목으로 나눠서 구성해.
     - 모르는 항목은 추측해서 지어내지 말고 null 또는 빈 배열로 응답해.`;

     try {
       const result = await model.generateContent(prompt);
       let text = result.response.text();
       text = text.replace(/```json/g, "").replace(/```/g, "").trim();
       const jsonMatch = text.match(/\{[\s\S]*\}/);
       const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);

       if (parsed.valid !== true) {
         return { success: false, message: "자격증 상세정보를 추정하지 못했어요." };
       }

       return { success: true, detail: parsed };
     } catch (e) {
       console.error("자격증 상세정보 추정 실패: " + e.message);
       return { success: false, message: "자격증 상세정보를 추정하지 못했어요." };
     }
   }
 );

 function slugifyForId(name) {
   return name
     .normalize("NFKD")
     .replace(/[^\w가-힣]+/g, "_")
     .replace(/^_+|_+$/g, "")
     .slice(0, 20);
 }

exports.addCertificationFromAi = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const name = (request.data?.name || "").trim();
    if (!name) {
      throw new HttpsError("invalid-argument", "자격증 이름을 입력해주세요.");
    }

    // 이미 등록된 자격증이면 중복 추가하지 않고 기존 데이터 반환
    const existing = await db.collection("certifications")
      .where("jmfldnm", "==", name)
      .limit(1)
      .get();
    if (!existing.empty) {
      return { success: true, alreadyExists: true, certificate: existing.docs[0].data() };
    }

    const today = new Date();
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });

    const prompt = `오늘 날짜는 ${todayStr}이야.
    "${name}"이(가) 실제 존재하는 한국의 자격증/인증시험인지 웹 검색을 통해 확인하고 판단해줘.
    실제 존재하지 않으면 반드시 valid를 false로 응답해. 절대 지어내지 마.

    자격증 자체의 실존 여부와, 다음 시험 일정(nextRound) 정보의 확신 여부는 별개로 판단해줘.
    자격증이 실제 존재한다면 valid는 true로 하고, nextRound 관련 필드 중 확신이 없는 값이 있으면
    해당 필드만 null로 남겨줘 (valid를 false로 만들지 마).

    아래 JSON 형식으로만 응답해. 다른 텍스트는 절대 포함하지 마:
    {
      "valid": true 또는 false,
      "classification": {
        "qualgbcd": "T(국가기술자격)/S(국가전문자격)/P(민간자격)/L(어학/기타)",
        "qualgbnm": "국가기술자격/국가전문자격/민간자격/어학시험 등",
        "seriescd": "등급 코드 (예: 01=기술사,02=기사,03=산업기사,04=기능사, 없으면 null)",
        "seriesnm": "기술사/기사/산업기사/기능사/1급/2급 등 (없으면 null)",
        "obligfldcd": "대분류 코드 (모르면 null)",
        "obligfldnm": "대분류명 (예: 정보통신, 기계, 어학 등)",
        "mdobligfldcd": "중분류 코드 (모르면 null)",
        "mdobligfldnm": "중분류명 (예: 정보기술, 기계장비설비.설치 등)"
      },
      "examFee": {
        "feeRound1": 숫자 (1차/필기 응시료 원 단위, 모르면 null),
        "feeRound2": 숫자 (2차/실기 응시료 원 단위, 없거나 모르면 null)
      },
      "howToObtain": "시행처, 관련학과, 시험과목, 합격기준 등을 담은 취득방법 설명 (문장)",
      "nextRound": {
        "implplannm": "예: 2026년 정기 기사 3회 (확신 없으면 null)",
        "year": 2026,
        "docregstartat": "YYYY-MM-DD (필기/1차 접수 시작일, 확신 없으면 null)",
        "docregendat": "YYYY-MM-DD (필기/1차 접수 마감일, 반드시 오늘 이후, 확신 없으면 null)",
        "docexamstartat": "YYYY-MM-DD (필기/1차 시험일, 확신 없으면 null)",
        "docexamendat": "YYYY-MM-DD (필기/1차 시험 종료일, 당일이면 시작일과 동일)",
        "docpassat": "YYYY-MM-DD (필기 합격자 발표일, 없으면 null)",
        "docsubmitstartat": "YYYY-MM-DD (실기 접수 시작일, 없으면 null)",
        "docsubmitendat": "YYYY-MM-DD (실기 접수 마감일, 없으면 null)",
        "pracexamstartat": "YYYY-MM-DD (실기 시험 시작일, 없으면 null)",
        "pracexamendat": "YYYY-MM-DD (실기 시험 종료일, 없으면 null)",
        "pracpassstartat": "YYYY-MM-DD (최종 발표 관련일, 없으면 null)",
        "pracpassendat": "YYYY-MM-DD (최종 합격자 발표일, 없으면 null)"
      }
    }

    규칙:
    - "오늘 이후로 가장 가까운 다가오는 회차" 기준으로 nextRound를 채워.
    - docregendat(접수마감)은 반드시 오늘(${todayStr}) 이후여야 해. 확신이 없으면 null로 둬.
    - 필기/실기 구분이 없는 시험은 실기 관련 필드는 모두 null로 해.
    - 날짜는 반드시 YYYY-MM-DD 형식으로만 응답해.
    - classification, examFee, howToObtain은 자격증이 실존하면 최대한 채워줘 (이 값들이 없다고 valid를 false로 하지는 마).`;

    let parsed;
    try {
      const result = await ai.models.generateContent({
        model: "gemini-3.1-flash-lite",
        contents: prompt,
      });
      let text = result.text;
      text = text.replace(/```json/g, "").replace(/```/g, "").trim();
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(jsonMatch ? jsonMatch[0] : text);
    } catch (e) {
      console.error("자격증 추가 AI 분석 실패: " + e.message);
      return { success: false, message: "자격증 정보를 확인하지 못했어요." };
    }

    if (parsed.valid !== true) {
      return { success: false, message: "실제 존재가 확인되지 않는 자격증이에요." };
    }

    const cls = parsed.classification || {};
    const fee = parsed.examFee || {};
    const round = parsed.nextRound || {};
    const howToObtain = (parsed.howToObtain || "").trim();

    // 자격증 기본 정보(취득방법/응시료)는 여전히 필수로 검증.
    // 단, 다음 회차 일정은 확신이 없을 수 있으므로 없으면 schedules 저장을 건너뛰고
    // 자격증 자체는 등록되도록 완화.
    if (!howToObtain || (fee.feeRound1 == null && fee.feeRound2 == null)) {
      return { success: false, message: "자격증 정보가 충분히 확인되지 않아 추가하지 못했어요." };
    }

    const toTimestamp = (dateStr) => {
      if (!dateStr) return null;
      const d = new Date(`${dateStr}T00:00:00+09:00`);
      if (isNaN(d.getTime())) return null;
      return admin.firestore.Timestamp.fromDate(d);
    };

    const hasValidSchedule =
      !!round.docregstartat && !!round.docregendat && !!round.docexamstartat;

    let docregendatTs = null;
    if (hasValidSchedule) {
      docregendatTs = toTimestamp(round.docregendat);
      if (!docregendatTs || docregendatTs.toMillis() <= Date.now()) {
        docregendatTs = null;
      }
    }
    const scheduleUsable = hasValidSchedule && !!docregendatTs;

    const jmcd = `AI${slugifyForId(name).toUpperCase()}`;
    const baseFields = {
      jmcd,
      jmfldnm: name,
      qualgbcd: cls.qualgbcd || null,
      qualgbnm: cls.qualgbnm || null,
      seriescd: cls.seriescd || null,
      seriesnm: cls.seriesnm || null,
      obligfldcd: cls.obligfldcd || null,
      obligfldnm: cls.obligfldnm || null,
      mdobligfldcd: cls.mdobligfldcd || null,
      mdobligfldnm: cls.mdobligfldnm || null,
    };

    const feeParts = [];
    if (fee.feeRound1 != null) feeParts.push(`1차: ${fee.feeRound1}`);
    if (fee.feeRound2 != null) feeParts.push(`2차: ${fee.feeRound2}`);

    const certRef = db.collection("certifications").doc(jmcd);
    const nowTs = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    batch.set(certRef, {
      ...baseFields,
      source: "AI",
      scheduleConfirmed: scheduleUsable,
      updatedAt: nowTs,
    });

    batch.set(certRef.collection("details").doc("examFee"), {
      ...baseFields,
      infogb: "응시수수료",
      contents: feeParts.join(", "),
      feeRound1: fee.feeRound1 ?? null,
      feeRound2: fee.feeRound2 ?? null,
      updatedat: nowTs,
    });

    batch.set(certRef.collection("details").doc("howToObtain"), {
      ...baseFields,
      infogb: "취득방법",
      contents: howToObtain,
      updatedat: nowTs,
    });

    if (scheduleUsable) {
      const scheduleId = `${jmcd}_${(round.docregstartat || "").replace(/-/g, "")}`;
      batch.set(certRef.collection("schedules").doc(scheduleId), {
        ...baseFields,
        implplannm: round.implplannm || null,
        year: round.year || today.getFullYear(),
        docregstartat: toTimestamp(round.docregstartat),
        docregendat: docregendatTs,
        docexamstartat: toTimestamp(round.docexamstartat),
        docexamendat: toTimestamp(round.docexamendat || round.docexamstartat),
        docpassat: toTimestamp(round.docpassat),
        docsubmitstartat: toTimestamp(round.docsubmitstartat),
        docsubmitendat: toTimestamp(round.docsubmitendat),
        pracregstartat: toTimestamp(round.docsubmitstartat),
        pracregendat: toTimestamp(round.docsubmitendat),
        pracexamstartat: toTimestamp(round.pracexamstartat),
        pracexamendat: toTimestamp(round.pracexamendat),
        pracpassstartat: toTimestamp(round.pracpassstartat),
        pracpassendat: toTimestamp(round.pracpassendat),
        sortdate: toTimestamp(round.docregstartat),
        updatedat: nowTs,
      });
    }

    try {
      await batch.commit();
    } catch (e) {
      console.error("자격증 추가 저장 실패: " + e.message);
      return { success: false, message: "자격증 정보를 저장하지 못했어요." };
    }

    const savedSnap = await certRef.get();
    return {
      success: true,
      alreadyExists: false,
      scheduleConfirmed: scheduleUsable,
      certificate: savedSnap.data(),
    };
  }
);
);
