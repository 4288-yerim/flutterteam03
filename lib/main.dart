import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:home_widget/home_widget.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:workmanager/workmanager.dart';
import 'appwidgets/app_widget_background.dart';
import 'appwidgets/app_widget_sync.dart';
import 'firebase_options.dart';
import 'notification/services/push_notification_service.dart';
import 'services/app_icon_service.dart';
import 'splash/screens/splash_screen.dart';
import 'theme.dart';

const _iconCheckTaskName = 'checkInactivityIconTask';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    '백그라운드 FCM 수신: ${message.messageId}',
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _iconCheckTaskName) {
      await AppIconService.checkAndUpdateIcon();
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await PushNotificationService.instance.initialize();

  await HomeWidget.registerInteractivityCallback(
    appWidgetBackgroundCallback,
  );

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
    urlScheme: 'naver' + dotenv.env['NAVER_CLIENT_ID']!,
    clientId: dotenv.env['NAVER_CLIENT_ID']!,
    clientSecret: dotenv.env['NAVER_CLIENT_SECRET']!,
    clientName: '따iT',
  );

  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    _iconCheckTaskName,
    _iconCheckTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.notRequired),
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
    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
