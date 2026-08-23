import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:backspace/screens/splash_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api/apis.dart';
import 'firebase_options.dart';
import 'helper/notification_service.dart';
import 'helper/theme_controller.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  log('Handling background message: ${message.messageId}');

  final data = message.data;
  if (data.isNotEmpty) {
    final senderId = data['senderId'] ?? data['fromId'] ?? '';
    final title = data['title'] ?? message.notification?.title ?? 'New Message';
    final body = data['body'] ?? message.notification?.body ?? '';
    final senderImage = data['senderImage'] ?? '';
    final type = data['type'] ?? 'chat';
    final photoUrl = (type == 'image' || type == 'Type.image') ? data['body'] : null;

    if (senderId.isNotEmpty) {
      await NotificationService.showMessageNotification(
        title: title,
        body: body,
        senderId: senderId,
        senderImage: senderImage,
        photoUrl: photoUrl,
        isGroup: type == 'group_chat',
      );
    }
  }
}

// Global object for accessing device screen size
late Size mq;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Edge-to-Edge System UI
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Force transparent system bars immediately (before first frame)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Set orientation to portrait only
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  await _initializeFirebase();
  await NotificationService.initialize();
  await ThemeController.initTheme();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const List<String> _systemFontFallback = [
    'sans-serif',
    'system-ui',
    '-apple-system',
    'BlinkMacSystemFont',
    'Roboto',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Defer non-critical setup until after the first frame renders for maximum startup smoothness
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (APIs.auth.currentUser != null) {
        APIs.startHeartbeat();
        APIs.getFirebaseMessagingToken();
        APIs.initInAppMessageListener();
      }

      // Listen to Firebase Auth state changes
      APIs.auth.authStateChanges().listen((user) {
        if (user != null) {
          APIs.startHeartbeat();
          APIs.getFirebaseMessagingToken();
          APIs.initInAppMessageListener();
        } else {
          APIs.stopHeartbeat();
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    APIs.stopHeartbeat();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (APIs.auth.currentUser != null) {
      if (state == AppLifecycleState.resumed) {
        APIs.startHeartbeat();
      } else if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached ||
          state == AppLifecycleState.hidden) {
        APIs.activeChatUserId = '';
        APIs.stopHeartbeat();
        APIs.updateActiveStatus(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          navigatorKey: APIs.navigatorKey,
          title: 'BackSpace',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            fontFamilyFallback: _systemFontFallback,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF6F6F6),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF007AFF)),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamilyFallback: _systemFontFallback,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            fontFamilyFallback: _systemFontFallback,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF161618),
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF007AFF)),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                fontFamilyFallback: _systemFontFallback,
              ),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

_initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  log('\nFirebase initialized');
}