import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'common/splash_page.dart';
import 'services/notification_service.dart';
import 'services/enhanced_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize both notification services
  await NotificationService.init();
  await EnhancedNotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Care Minder",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashPage(), // splash page first
    );
  }
}
