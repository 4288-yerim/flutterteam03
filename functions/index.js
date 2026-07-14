const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

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
const OTP_TTL_MS = 5 * 60 * 1000; // 5분
const RESEND_COOLDOWN_MS = 60 * 1000; // 60초
const MAX_ATTEMPTS = 5;

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
      from: `"우리 서비스" <${EMAIL_USER.value()}>`,
      to: email,
      subject: "[우리 서비스] 이메일 인증코드",
      html: `
        <div style="font-family: sans-serif; padding: 24px;">
          <h2>이메일 인증코드</h2>
          <p>아래 6자리 코드를 앱에 입력해주세요. 5분 후 만료됩니다.</p>
          <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px;">${code}</div>
        </div>
      `,
    });

    return { success: true };
  }
);

/**
 * 2단계: 인증코드 검증 + (성공 시) Firebase Auth 계정 생성
 * 요청: { email, code, password }
 * 성공하면 emailVerified: true 상태로 계정을 만들고 커스텀 토큰을 반환.
 * 클라이언트는 이 토큰으로 signInWithCustomToken() 호출 후 약관동의 -> Firestore 유저 문서 생성 진행.
 */
exports.verifyOtp = onCall(
  { secrets: [OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();
    const code = (request.data?.code || "").trim();
    const password = request.data?.password || "";

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }
    if (!/^\d{6}$/.test(code)) {
      throw new HttpsError("invalid-argument", "인증코드는 6자리 숫자입니다.");
    }
    if (typeof password !== "string" || password.length < 6) {
      throw new HttpsError("invalid-argument", "비밀번호는 6자 이상이어야 합니다.");
    }

    const docRef = db.collection(OTP_COLLECTION).doc(email);
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

    // 코드 일치 -> 이 시점에 비로소 Firebase Auth 계정 생성
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

    await docRef.delete();

    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    return { customToken, uid: userRecord.uid };
  }
);