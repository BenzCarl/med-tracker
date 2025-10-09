// lib/services/enhanced_notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';

// Helper function to reduce stock
Future<void> _reduceStock(String? medicineName, String? userId) async {
  if (medicineName == null || userId == null) return;
  
  try {
    final medicineQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medicines')
        .where('name', isEqualTo: medicineName)
        .limit(1)
        .get();
    
    if (medicineQuery.docs.isNotEmpty) {
      final doc = medicineQuery.docs.first;
      final currentStock = doc.data()['initialStock'] ?? 0;
      
      if (currentStock > 0) {
        await doc.reference.update({
          'initialStock': currentStock - 1,
          'lastIntakeAt': FieldValue.serverTimestamp(),
        });
        
        // Log to history
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .add({
          'medicineName': medicineName,
          'status': 'Auto-Taken',
          'timestamp': FieldValue.serverTimestamp(),
          'stockBefore': currentStock,
          'stockAfter': currentStock - 1,
        });
      }
    }
  } catch (e) {
    print('Error reducing stock: $e');
  }
}

class EnhancedNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  
  /// Initialize with enhanced Android 12-14 support
  static Future<bool> init() async {
    if (_isInitialized) return true;
    
    try {
      // Initialize timezone
      tzdata.initializeTimeZones();
      
      // Request ALL necessary permissions for Android 12-14
      await requestAllPermissions();
      
      // Create high priority notification channel
      const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
        'med_channel_high',
        'Medicine Reminders',
        description: 'High priority medicine reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 33, 150, 243),
        showBadge: true,
      );
      
      // Create urgent notification channel (Android 12+)
      const AndroidNotificationChannel urgentChannel = AndroidNotificationChannel(
        'med_channel_urgent',
        'Urgent Medicine Alerts',
        description: 'Urgent medicine alerts that need immediate attention',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
        showBadge: true,
      );
      
      // Android initialization with icon
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );
      
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      
      // Create notification channels
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(highChannel);
        await androidPlugin.createNotificationChannel(urgentChannel);
        
        // Request exact alarm permission for Android 12+
        if (Platform.isAndroid) {
          final androidInfo = await androidPlugin.getNotificationAppLaunchDetails();
          print('Notification launch details: ${androidInfo?.notificationResponse}');
        }
      }
      
      _isInitialized = true;
      print('✅ Enhanced Notifications initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing enhanced notifications: $e');
      return false;
    }
  }
  
  /// Request ALL permissions needed for Android 12-14
  static Future<bool> requestAllPermissions() async {
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      print('Notification permission: $notificationStatus');
      
      // Request exact alarm permission (Android 12+)
      if (Platform.isAndroid) {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
        print('Exact alarm permission: $exactAlarmStatus');
        
        // Request system alert window (for full-screen intent)
        final alertStatus = await Permission.systemAlertWindow.request();
        print('System alert permission: $alertStatus');
        
        // Request ignore battery optimizations
        final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
        print('Battery optimization permission: $batteryStatus');
      }
      
      return notificationStatus.isGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
  
  /// Fallback: reconcile due doses on app open/resume
  static Future<void> reconcileDueDoses({Duration lookback = const Duration(minutes: 120)}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final schedulesSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .get();

      final now = DateTime.now();
      for (final doc in schedulesSnap.docs) {
        final data = doc.data();
        final name = data['medicineName'] as String?;
        final timeStr = data['time'] as String?;
        final days = (data['days'] as List?)?.cast<String>() ?? const <String>[];
        if (name == null || timeStr == null || days.isEmpty) continue;

        // Check if today is an allowed day
        final dayShort = DateFormat('EEE').format(now);
        if (!days.contains(dayShort)) continue;

        // Parse time for today
        DateTime scheduledToday;
        try {
          final t = DateFormat.jm().parse(timeStr);
          scheduledToday = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        } catch (_) {
          continue;
        }

        final diff = now.difference(scheduledToday);
        if (diff.isNegative || diff > lookback) continue;

        // Check if we already logged a taken event
        final sinceTs = Timestamp.fromDate(scheduledToday.subtract(const Duration(minutes: 15)));
        final historySnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .where('medicineName', isEqualTo: name)
            .where('timestamp', isGreaterThanOrEqualTo: sinceTs)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (historySnap.docs.isNotEmpty) continue;

        // Reduce stock
        final medsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medicines')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
        if (medsSnap.docs.isEmpty) continue;
        
        final medDoc = medsSnap.docs.first;
        final medData = medDoc.data();
        final currentStock = (medData['initialStock'] is int)
            ? medData['initialStock'] as int
            : int.tryParse('${medData['initialStock']}') ?? 0;
            
        if (currentStock <= 0) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .add({
            'medicineName': name,
            'status': 'Taken',
            'timestamp': FieldValue.serverTimestamp(),
          });
          continue;
        }

        await medDoc.reference.update({'initialStock': currentStock - 1});
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .add({
          'medicineName': name,
          'status': 'Taken',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('reconcileDueDoses error: $e');
    }
  }
  
  /// Schedule with multiple fallback methods for Android 12-14
  static Future<bool> scheduleEnhancedReminder({
    required String medicineName,
    required String dosage,
    required TimeOfDay time,
    required List<String> days,
    required String interval,
    bool enableStockReduction = true,
  }) async {
    try {
      await init();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      
      // Map days to weekday integers
      final dayMap = {
        "Mon": DateTime.monday,
        "Tue": DateTime.tuesday,
        "Wed": DateTime.wednesday,
        "Thu": DateTime.thursday,
        "Fri": DateTime.friday,
        "Sat": DateTime.saturday,
        "Sun": DateTime.sunday,
      };
      
      final weekdaysInts = days
          .map((d) => dayMap[d] ?? 0)
          .where((i) => i != 0)
          .toList();
      
      if (weekdaysInts.isEmpty) return false;
      
      // Try exact alarm with full-screen intent
      bool scheduled = await _scheduleExactWithFullScreen(
        medicineName: medicineName,
        dosage: dosage,
        hour: time.hour,
        minute: time.minute,
        weekdays: weekdaysInts,
      );
      
      // Schedule immediate test to verify it works
      await showInstantNotification(
        title: "✅ Schedule Set!",
        body: "Reminders for $medicineName are now active",
      );
      
      // Schedule a test notification 10 seconds from now to verify notifications work
      await _scheduleTestNotification(
        medicineName: medicineName,
        dosage: dosage,
      );
      
      return scheduled;
    } catch (e) {
      print('Error in enhanced scheduling: $e');
      return false;
    }
  }
  
  /// Schedule a test notification 10 seconds from now
  static Future<void> _scheduleTestNotification({
    required String medicineName,
    required String dosage,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final testTime = now.add(const Duration(seconds: 10));
      
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'med_channel_urgent',
        'Urgent Medicine Alerts',
        channelDescription: 'Test notification',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color.fromARGB(255, 33, 150, 243),
        ledColor: Color.fromARGB(255, 33, 150, 243),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'Medicine Time',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      
      await _notifications.zonedSchedule(
        999999, // Special ID for test
        "🔔 TEST: $medicineName",
        "This is how your reminder will look!\nDosage: $dosage",
        testTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('🧪 Test notification scheduled for 10 seconds from now');
    } catch (e) {
      print('Error scheduling test notification: $e');
    }
  }

  /// Schedule with exact alarm and full-screen intent
  static Future<bool> _scheduleExactWithFullScreen({
    required String medicineName,
    required String dosage,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'med_channel_urgent',
        'Urgent Medicine Alerts',
        channelDescription: 'Time-critical medicine reminders',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color.fromARGB(255, 33, 150, 243),
        ledColor: Color.fromARGB(255, 33, 150, 243),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'Medicine Time',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      
      for (final weekday in weekdays) {
        final scheduledDate = _nextInstanceOfWeekdayAndTime(
          hour,
          minute,
          weekday,
        );
        
        final id = _generateId(medicineName, weekday);
        
        await _notifications.zonedSchedule(
          id,
          "💊 Take your $medicineName",
          "Dosage: $dosage\nTap to mark as taken",
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: jsonEncode({
            'medicineName': medicineName,
            'dosage': dosage,
            'type': 'medicine_reminder',
          }),
        );
        
        print('📅 [EXACT+FULLSCREEN] Scheduled for $medicineName on weekday $weekday');
      }
      
      return true;
    } catch (e) {
      print('Error in exact scheduling: $e');
      return false;
    }
  }
  
  /// Show instant notification with high priority
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    try {
      await init();
      
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'med_channel_high',
        'Medicine Reminders',
        channelDescription: 'Medicine reminder notifications',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        color: Color.fromARGB(255, 33, 150, 243),
        ledColor: Color.fromARGB(255, 33, 150, 243),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'Medicine Reminder',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      );
      
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
      
      print('🔔 Instant notification shown: $title');
    } catch (e) {
      print('Error showing instant notification: $e');
    }
  }
  
  // Helper functions
  static int _generateId(String tag, int weekday) {
    final base = tag.hashCode.abs() % 1000000;
    return base * 10 + (weekday % 10);
  }
  
  static tz.TZDateTime _nextInstanceOfWeekdayAndTime(
    int hour,
    int minute,
    int weekday,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    return scheduled;
  }
  
  /// Cancel all notifications for a medicine
  static Future<void> cancelNotifications(String medicineName) async {
    try {
      // Cancel flutter local notifications
      for (var day = 1; day <= 7; day++) {
        final id = _generateId(medicineName, day);
        await _notifications.cancel(id);
      }
      print('🗑️ Cancelled all notifications for $medicineName');
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }
}

// Background handler for notification taps
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  try {
    final payload = response.payload;
    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['type'] == 'stock_reduction') {
      _reduceStock(data['medicineName'] as String?, data['userId'] as String?);
    }
  } catch (_) {
    // ignore
  }
}

// Foreground handler
void _onNotificationResponse(NotificationResponse response) {
  try {
    final payload = response.payload;
    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['type'] == 'stock_reduction') {
      _reduceStock(data['medicineName'] as String?, data['userId'] as String?);
    }
  } catch (_) {
    // ignore
  }
}
