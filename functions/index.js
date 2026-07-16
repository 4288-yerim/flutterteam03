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

/**
 * 2단계: 인증코드 검증만 수행. 이 시점엔 Firebase Auth 계정을 만들지 않는다.
 * 요청: { email, code }
 * 성공하면 "이 이메일은 방금 인증됨"을 증명하는 verificationToken을 발급한다.
 * 이 토큰은 15분간 유효하며, 그 안에 completeSignup을 호출해야 실제 계정이 생긴다.
 * (즉 약관동의까지 마치지 않으면 Firebase Auth / Firestore 어디에도 아무 흔적이 남지 않음)
 */
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

/**
 * 3단계: 약관동의까지 완료된 시점에 호출.
 * 요청: { email, password, verificationToken, agreements: { age, terms, privacy, marketing } }
 * verificationToken이 유효할 때만 Firebase Auth 계정 생성 + Firestore 유저 문서 생성을 이어서 수행.
 * 유저 문서 생성이 실패하면 방금 만든 Auth 계정도 롤백(삭제)한다.
 */
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

/**
 * 비밀번호 재설정 1단계: "이미 가입된" 계정에게만 인증코드 발송.
 * sendOtp와 반대로, 계정이 없으면 코드 자체를 보내지 않는다.
 * 요청: { email }
 */
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