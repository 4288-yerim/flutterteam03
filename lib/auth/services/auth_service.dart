import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:cloud_functions/cloud_functions.dart';

class AuthResult {
  final User? user;
  final bool isNewUser;
  final SocialSignupTicket? signupTicket;

  AuthResult({this.user, required this.isNewUser, this.signupTicket});
}

class SocialSignupTicket {
  final String provider;
  final String signupToken;
  final String? email;
  final String? suggestedNickname;

  SocialSignupTicket({
    required this.provider,
    required this.signupToken,
    this.email,
    this.suggestedNickname,
  });
}

class AuthService {
  AuthService._();

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<AuthResult?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (!isNewUser) {
        return AuthResult(user: userCredential.user, isNewUser: false);
      }

      await userCredential.user?.delete();
      await _firebaseAuth.signOut();

      return AuthResult(
        user: null,
        isNewUser: true,
        signupTicket: SocialSignupTicket(
          provider: 'google',
          signupToken: googleAuth.idToken ?? '',
          email: googleUser.email,
          suggestedNickname: googleUser.displayName,
        ),
      );
    } on GoogleSignInException catch (e) {
      debugPrint('🔴 GoogleSignInException: ${e.code} ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 FirebaseAuthException: ${e.code} ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('🔴 알 수 없는 에러: $e');
      debugPrint('$st');
      return null;
    }
  }

  static Future<void> _googleSignOut() async {
    await _googleSignIn.signOut();
  }

  static Future<AuthResult?> signInWithKakao() async {
    try {
      final isInstalled = await kakao.isKakaoTalkInstalled();
      final kakao.OAuthToken token = isInstalled
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();

      final kakao.User kakaoUser = await kakao.UserApi.instance.me();

      final result = await _exchangeForFirebaseCustomToken(
        provider: 'kakao',
        accessToken: token.accessToken,
        providerUserId: kakaoUser.id.toString(),
        email: kakaoUser.kakaoAccount?.email,
        nickname: kakaoUser.kakaoAccount?.profile?.nickname,
      );
      if (result == null) return null;

      final isNewUser = result['isNewUser'] as bool? ?? false;

      if (!isNewUser) {
        final customToken = result['firebaseCustomToken'] as String?;
        if (customToken == null) return null;
        final userCredential = await _firebaseAuth.signInWithCustomToken(customToken);
        return AuthResult(user: userCredential.user, isNewUser: false);
      }

      final signupToken = result['signupToken'] as String?;
      if (signupToken == null) return null;
      return AuthResult(
        user: null,
        isNewUser: true,
        signupTicket: SocialSignupTicket(
          provider: 'kakao',
          signupToken: signupToken,
          email: kakaoUser.kakaoAccount?.email,
          suggestedNickname: kakaoUser.kakaoAccount?.profile?.nickname,
        ),
      );
    } on kakao.KakaoAuthException catch (e) {
      debugPrint('카카오 인증 실패: ${e.error} / ${e.errorDescription}');
      return null;
    } on kakao.KakaoClientException catch (e) {
      debugPrint('카카오 클라이언트 오류: ${e.reason} / ${e.message}');
      return null;
    } catch (e) {
      debugPrint('카카오 로그인 실패: $e');
      return null;
    }
  }

  static Future<AuthResult?> signInWithNaver() async {
    try {
      final bool isLogin = await NaverLoginSDK.login();
      if (!isLogin) return null;

      final String accessToken = await NaverLoginSDK.getAccessToken();

      final NaverLoginProfile? profile = await NaverLoginSDK.profile();
      if (profile == null) {
        debugPrint('네이버 프로필 조회 실패: profile이 null');
        return null;
      }

      final result = await _exchangeForFirebaseCustomToken(
        provider: 'naver',
        accessToken: accessToken,
        providerUserId: profile.id ?? '',
        email: profile.email,
        nickname: profile.nickName,
      );
      if (result == null) return null;

      final isNewUser = result['isNewUser'] as bool? ?? false;

      if (!isNewUser) {
        final customToken = result['firebaseCustomToken'] as String?;
        if (customToken == null) return null;
        final userCredential = await _firebaseAuth.signInWithCustomToken(customToken);
        return AuthResult(user: userCredential.user, isNewUser: false);
      }

      final signupToken = result['signupToken'] as String?;
      if (signupToken == null) return null;
      return AuthResult(
        user: null,
        isNewUser: true,
        signupTicket: SocialSignupTicket(
          provider: 'naver',
          signupToken: signupToken,
          email: profile.email,
          suggestedNickname: profile.nickName,
        ),
      );
    } catch (e) {
      debugPrint('네이버 로그인 실패: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _exchangeForFirebaseCustomToken({
    required String provider,
    required String accessToken,
    required String providerUserId,
    String? email,
    String? nickname,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'auth${provider[0].toUpperCase()}${provider.substring(1)}',
      );
      final result = await callable.call({
        'accessToken': accessToken,
        'providerUserId': providerUserId,
        'email': email,
        'nickname': nickname,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[$provider] Cloud Function 오류: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[$provider] Custom token 요청 중 오류: $e');
      return null;
    }
  }

  static Future<AuthResult?> completeSocialSignup({
    required SocialSignupTicket ticket,
    required Map<String, bool> agreements,
    String? goalCertificateId,
    required String nickname,
    String? bio,
  }) async {
    if (ticket.provider == 'google') {
      try {
        final credential = GoogleAuthProvider.credential(idToken: ticket.signupToken);
        final userCredential = await _firebaseAuth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) return null;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'loginProvider': 'GOOGLE',
          'role': 'USER',
          'status': 'ACTIVE',
          'loginFailCount': 0,
          'reportCount': 0,
          'goalCertificateId': goalCertificateId,
          'nickname': nickname,
          'bio': bio,
          'termsAgreed': agreements['terms'] ?? false,
          'privacyAgreed': agreements['privacy'] ?? false,
          'marketingAgreed': agreements['marketing'] ?? false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return AuthResult(user: user, isNewUser: true);
      } catch (e) {
        debugPrint('구글 가입 완료 실패: $e');
        return null;
      }
    }


    try {
      final callable = _functions.httpsCallable('completeSocialSignup');
      final result = await callable.call({
        'signupToken': ticket.signupToken,
        'agreements': agreements,
        'goalCertificateId': goalCertificateId,
        'nickname': nickname,
        'bio': bio,
      });

      final body = Map<String, dynamic>.from(result.data as Map);
      final customToken = body['firebaseCustomToken'] as String?;
      if (customToken == null) return null;

      final userCredential = await _firebaseAuth.signInWithCustomToken(customToken);
      return AuthResult(user: userCredential.user, isNewUser: true);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[${ticket.provider}] 가입 완료 실패: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[${ticket.provider}] 가입 완료 요청 중 오류: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _safeSignOut(() => _googleSignIn.signOut()),
      _safeSignOut(() => kakao.UserApi.instance.logout()),
      _safeSignOut(() => NaverLoginSDK.logout()),
    ]);
  }

  static Future<void> _safeSignOut(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {
    }
  }
}