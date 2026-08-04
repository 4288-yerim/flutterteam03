const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

const db = admin.firestore();

const { saveInitialGoal } = require("../certification/certification");

const EMAIL_USER = defineSecret("EMAIL_USER");
const EMAIL_PASS = defineSecret("EMAIL_PASS");
const OTP_PEPPER = defineSecret("OTP_PEPPER");

const OTP_COLLECTION = "otp_verifications";
const OTP_TTL_MS = 5 * 60 * 1000;
const VERIFIED_TTL_MS = 15 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_ATTEMPTS = 5;

const PASSWORD_RESET_COLLECTION = "password_reset_otps";

function isValidEmail(email) {
  return typeof email === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function hashCode(code, pepper) {
  return crypto.createHash("sha256").update(`${code}:${pepper}`).digest("hex");
}

function generateCode() {
  return String(crypto.randomInt(0, 1000000)).padStart(6, "0");
}

function buildTransporter(user, pass) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });
}

exports.sendOtp = onCall(
  { secrets: [EMAIL_USER, EMAIL_PASS, OTP_PEPPER] },
  async (request) => {
    const email = (request.data?.email || "").trim().toLowerCase();

    if (!isValidEmail(email)) {
      throw new HttpsError("invalid-argument", "이메일 형식이 올바르지 않습니다.");
    }

    try {
      const existing = await admin.auth().getUserByEmail(email);
      if (existing) {
        throw new HttpsError("already-exists", "이미 가입된 이메일입니다.");
      }
    } catch (err) {
      if (err.code !== "auth/user-not-found") {
        if (err instanceof HttpsError) throw err;
        throw new HttpsError("internal", "계정 확인 중 오류가 발생했습니다.");
      }
    }

    const docRef = db.collection(OTP_COLLECTION).doc(email);
    const snap = await docRef.get();

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
      await admin.auth().deleteUser(userRecord.uid).catch(() => {});
      throw new HttpsError("internal", "가입 처리 중 오류가 발생했습니다. 다시 시도해주세요.");
    }

    if (goalCertificateId) {
      await saveInitialGoal(userRecord.uid, goalCertificateId).catch((e) => {
        console.error("목표 자격증 저장 실패(completeSignup): " + e.message);
      });
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