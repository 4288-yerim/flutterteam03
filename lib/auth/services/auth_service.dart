import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

/// 소셜 로그인 결과를 라우팅(홈 vs 약관동의)에 활용하기 위한 래퍼
class AuthResult {
  final User? user;
  final bool isNewUser;

  AuthResult({required this.user, required this.isNewUser});
}

class AuthService {
  AuthService._();

  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // ---------------------------------------------------------------------
  // Google 로그인 (google_sign_in 7.x API로 마이그레이션)
  // ---------------------------------------------------------------------
  static Future<AuthResult?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // authentication은 이제 동기 getter이며 idToken만 제공
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      return AuthResult(
        user: userCredential.user,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // 사용자가 로그인 취소
      }
      debugPrint('구글 로그인 실패(GoogleSignIn): ${e.code} ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('구글 로그인 실패(Firebase): ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('구글 로그인 실패: $e');
      return null;
    }
  }

  // signOut도 v7에서는 방식이 조금 다릅니다
  static Future<void> _googleSignOut() async {
    await _googleSignIn.signOut();
  }

  // ---------------------------------------------------------------------
  // 카카오 로그인 (변경 없음)
  // ---------------------------------------------------------------------
  static Future<AuthResult?> signInWithKakao() async {
    try {
      final isInstalled = await kakao.isKakaoTalkInstalled();
      final kakao.OAuthToken token = isInstalled
          ? await kakao.UserApi.instance.loginWithKakaoTalk()
          : await kakao.UserApi.instance.loginWithKakaoAccount();

      final kakao.User kakaoUser = await kakao.UserApi.instance.me();

      final customToken = await _exchangeForFirebaseCustomToken(
        provider: 'kakao',
        accessToken: token.accessToken,
        providerUserId: kakaoUser.id.toString(),
        email: kakaoUser.kakaoAccount?.email,
        nickname: kakaoUser.kakaoAccount?.profile?.nickname,
      );
      if (customToken == null) return null;

      final userCredential =
      await _firebaseAuth.signInWithCustomToken(customToken);
      return AuthResult(
        user: userCredential.user,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } catch (e) {
      debugPrint('카카오 로그인 실패: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 네이버 로그인 (naver_login_sdk로 마이그레이션)
  //
  // 이전 API: FlutterNaverLogin.logIn() → NaverLoginResult
  // 새 API: NaverLoginSDK.login() → bool (로그인 성공 여부만 반환)
  //         프로필/토큰은 별도 함수로 조회해야 함
  // ---------------------------------------------------------------------
  static Future<AuthResult?> signInWithNaver() async {
    try {
      final bool isLogin = await NaverLoginSDK.login();
      if (!isLogin) return null; // 로그인 취소/실패

      // 액세스 토큰 조회
      final String accessToken = await NaverLoginSDK.getAccessToken();

      // 프로필 조회 (NaverLoginProfile로 파싱)
      final profileResponse = await NaverLoginSDK.profile();
      final profile = NaverLoginProfile.fromJson(response: profileResponse);

      final customToken = await _exchangeForFirebaseCustomToken(
        provider: 'naver',
        accessToken: accessToken,
        providerUserId: profile.id ?? '',
        email: profile.email,
        nickname: profile.nickName,
      );
      if (customToken == null) return null;

      final userCredential =
      await _firebaseAuth.signInWithCustomToken(customToken);
      return AuthResult(
        user: userCredential.user,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
      );
    } catch (e) {
      debugPrint('네이버 로그인 실패: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 백엔드 Custom Token 교환 (변경 없음)
  // ---------------------------------------------------------------------
  static Future<String?> _exchangeForFirebaseCustomToken({
    required String provider,
    required String accessToken,
    required String providerUserId,
    String? email,
    String? nickname,
  }) async {
    final baseUrl = dotenv.env['BACKEND_BASE_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      debugPrint('[$provider] BACKEND_BASE_URL이 설정되지 않았습니다. .env를 확인하세요.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/$provider'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'accessToken': accessToken,
          'providerUserId': providerUserId,
          'email': email,
          'nickname': nickname,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[$provider] Custom token 발급 실패: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['firebaseCustomToken'] as String?;
    } catch (e) {
      debugPrint('[$provider] Custom token 요청 중 오류: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 로그아웃
  // ---------------------------------------------------------------------
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
      // 해당 프로바이더로 로그인하지 않은 상태라면 무시
    }
  }
}