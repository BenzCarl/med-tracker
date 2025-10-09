import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'common/splash_page.dart';
import 'services/notification_service.dart';
import 'services/enhanced_notification_service.dart';

// Global navigation key for handling notification taps
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize both notification services
  await NotificationService.init();
  await EnhancedNotificationService.init();

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
    // Check if app was launched from notification
    _checkNotificationLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkNotificationLaunch() async {
    // Small delay to ensure navigator is ready
    await Future.delayed(const Duration(milliseconds: 500));
    await NotificationService.checkAndHandleLaunchDetails();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: "Care Minder",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashPage(), // splash page first
    );
  }
}
