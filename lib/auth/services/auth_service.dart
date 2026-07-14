import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;

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
    debugPrint('🟡 구글 로그인 authenticate() 호출 시작');
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      debugPrint('🟢 authenticate 성공: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      debugPrint('🟢 idToken 확보: ${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      debugPrint('🟢 Firebase 로그인 성공: ${userCredential.user?.uid}');
      return AuthResult(
        user: userCredential.user,
        isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
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

  // signOut도 v7에서는 방식이 조금 다릅니다
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

      final tokenResult = await _exchangeForFirebaseCustomToken(
        provider: 'kakao',
        accessToken: token.accessToken,
        providerUserId: kakaoUser.id.toString(),
        email: kakaoUser.kakaoAccount?.email,
        nickname: kakaoUser.kakaoAccount?.profile?.nickname,
      );
      final customToken = tokenResult?['firebaseCustomToken'] as String?;
      if (customToken == null) return null;

      final userCredential =
      await _firebaseAuth.signInWithCustomToken(customToken);
      return AuthResult(
        user: userCredential.user,
        isNewUser: tokenResult?['isNewUser'] as bool? ?? false,
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

      final String accessToken = await NaverLoginSDK.getAccessToken();

      // profile()이 nullable을 반환하므로 ? 로 받고 null 체크
      final NaverLoginProfile? profile = await NaverLoginSDK.profile();
      if (profile == null) {
        debugPrint('네이버 프로필 조회 실패: profile이 null');
        return null;
      }

      final tokenResult = await _exchangeForFirebaseCustomToken(
        provider: 'naver',
        accessToken: accessToken,
        providerUserId: profile.id ?? '',
        email: profile.email,
        nickname: profile.nickName,
      );
      final customToken = tokenResult?['firebaseCustomToken'] as String?;
      if (customToken == null) return null;

      final userCredential =
      await _firebaseAuth.signInWithCustomToken(customToken);
      return AuthResult(
        user: userCredential.user,
        isNewUser: tokenResult?['isNewUser'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('네이버 로그인 실패: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 백엔드 Custom Token 교환 (변경 없음)
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>?> _exchangeForFirebaseCustomToken({
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
        Uri.parse('$baseUrl/api/auth/$provider'),
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
      debugPrint('[$provider] 서버 응답: $body');
      return body;
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