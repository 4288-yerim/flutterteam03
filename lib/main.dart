import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'splash/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'services/app_icon_service.dart';
import 'package:flutterteam03/services/notification_service.dart';

const _iconCheckTaskName = 'checkInactivityIconTask';

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

  await NotificationService.instance.initialize();

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
    AppIconService.onAppOpened(); // 첫 실행 시에도 체크
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
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}