import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'appwidgets/app_widget_background.dart';
import 'appwidgets/app_widget_sync.dart';
import 'firebase_options.dart';
import 'notification/services/push_notification_service.dart';
import 'services/app_icon_service.dart';
import 'services/theme_mode_service.dart';
import 'splash/screens/splash_screen.dart';
import 'theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('백그라운드 FCM 수신: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeModeService.instance.initialize();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ThemeModeService.instance.startAuthSync();
  AppWidgetSync.startAuthSync();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await PushNotificationService.instance.initialize();

  await HomeWidget.registerInteractivityCallback(appWidgetBackgroundCallback);

  try {
    await AppWidgetSync.syncAll();
  } catch (error, stackTrace) {
    debugPrint('초기 홈 위젯 동기화 실패: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  await GoogleSignIn.instance.initialize(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
  );

  await KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']!);

  await NaverLoginSDK.initialize(
    urlScheme: 'naver${dotenv.env['NAVER_CLIENT_ID']!}',
    clientId: dotenv.env['NAVER_CLIENT_ID']!,
    clientSecret: dotenv.env['NAVER_CLIENT_SECRET']!,
    clientName: '따iT',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    AppIconService.onAppOpened();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.handleInitialMessage();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppIconService.onAppOpened();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeModeService.instance.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
