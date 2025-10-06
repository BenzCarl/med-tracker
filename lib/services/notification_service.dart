// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize notifications with proper channel setup
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database
      tzdata.initializeTimeZones();

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'med_channel', // id
        'Medicine Reminders', // title
        description: 'Reminders to take your medicines',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Initialize the plugin
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );

      await _notifications.initialize(initSettings);

      // Create the channel (required for Android 8.0+)
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      _isInitialized = true;
      print('✅ Notifications initialized successfully');
    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  static int _generateId(String tag, int weekday) {
    final base = tag.hashCode.abs() % 1000000;
    return base * 10 + (weekday % 10);
  }

  static int _generateIdWithSlot(String tag, int weekday, int slotIndex) {
    final base = tag.hashCode.abs() % 100000;
    // Compose ID as: base * 100 + weekday(1..7)*10 + slot(0..9)
    return base * 100 + (weekday % 10) * 10 + (slotIndex % 10);
  }

  static Future<void> cancelNotificationsForTag(String tag) async {
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      final id = _generateId(tag, day);
      await _notifications.cancel(id);
    }
    print('📋 Cancelled all notifications for: $tag');
  }

  static Future<void> scheduleWeekly({
    required String tag,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    try {
      await init(); // Ensure notifications are initialized

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      int scheduledCount = 0;

      for (final weekday in weekdays) {
        final scheduledDate = _nextInstanceOfWeekdayAndTime(
          hour,
          minute,
          weekday,
        );
        final id = _generateId(tag, weekday);

        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

        scheduledCount++;
        print(
          '📅 Scheduled notification for $tag on weekday $weekday at $hour:$minute',
        );
      }

      print('✅ Successfully scheduled $scheduledCount notifications for: $tag');
    } catch (e) {
      print('❌ Error scheduling notifications for $tag: $e');
      rethrow;
    }
  }

  /// Schedule multiple times per selected weekday using an hourly interval anchor
  static Future<void> scheduleIntervalWeekly({
    required String tag,
    required String title,
    required String body,
    required int anchorHour,
    required int anchorMinute,
    required int intervalHours, // 2,4,6,12
    required List<int> weekdays,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final int occurrencesPerDay = (24 / intervalHours).floor();
      for (final weekday in weekdays) {
        for (int i = 0; i < occurrencesPerDay; i++) {
          final int hour = (anchorHour + i * intervalHours) % 24;
          final int minute = anchorMinute;
          final scheduledDate = _nextInstanceOfWeekdayAndTime(
            hour,
            minute,
            weekday,
          );
          final id = _generateIdWithSlot(tag, weekday, i);

          await _notifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );

          print('📅 Interval schedule $tag weekday $weekday at $hour:$minute (slot $i)');
        }
      }

      print('✅ Interval weekly scheduling completed for: $tag');
    } catch (e) {
      print('❌ Error in interval weekly scheduling for $tag: $e');
      rethrow;
    }
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

    print('⏰ Next notification for weekday $weekday: $scheduled');
    return scheduled;
  }

  /// Test if notifications are working
  static Future<void> scheduleTestNotification() async {
    try {
      await init();
      // Ensure permissions for Android 13+
      await requestPermissions();

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(seconds: 10));

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      try {
        await _notifications.zonedSchedule(
        999,
        "Test Reminder - Care Minder",
        "This is a test notification to verify that reminders are working properly.",
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        // Fallback: show immediate notification if scheduling fails
        await _notifications.show(999, "Test Reminder - Care Minder",
            "This is an instant fallback test notification.", details);
      }

      // Log to history so it appears in NotificationPage
      await _logNotificationHistory(
        status: 'Test',
        medicineName: 'Test Reminder - Care Minder',
      );

      print('🧪 Test notification scheduled for 10 seconds from now');
    } catch (e) {
      print('❌ Error scheduling test notification: $e');
    }
  }

  /// Show instant notification for testing
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(0, title, body, details);
      // Log to history so it appears in NotificationPage
      await _logNotificationHistory(
        status: 'Test',
        medicineName: title,
      );
      print('🔔 Instant notification shown: $title');
    } catch (e) {
      print('❌ Error showing instant notification: $e');
    }
  }

  /// Check pending notifications (for debugging) - FIXED RETURN TYPE
  static Future<void> debugPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    print('📋 Pending notifications: ${pending.length}');
    for (var notif in pending) {
      print('  - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
    }
    // No return value needed since it's Future<void>
  }

  /// Get all pending notifications (if you need to return the list)
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Schedule a daily notification at specific time
  static Future<void> scheduleDaily({
    required String tag,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final scheduledDate = _nextInstanceOfTime(hour, minute);

      await _notifications.zonedSchedule(
        tag.hashCode.abs() % 100000,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('📅 Daily notification scheduled for $tag at $hour:$minute');
    } catch (e) {
      print('❌ Error scheduling daily notification for $tag: $e');
    }
  }

  /// Calculate the next occurrence of a specific time
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    return await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  /// Request notification permissions (mainly for Android 13+)
  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission() ??
          false;
    }

    return false;
  }

  /// Request exact alarm permission on supported Android versions
  static Future<bool> requestExactAlarmsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation == null) return false;

    try {
      final bool? granted =
          await androidImplementation.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancel all pending notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  /// Simple notification without scheduling
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'med_channel',
            'Medicine Reminders',
            channelDescription: 'Reminders to take your medicines',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(id, title, body, details);
      // Log generic notifications as well
      await _logNotificationHistory(
        status: 'Reminder',
        medicineName: title,
      );
    } catch (e) {
      print('❌ Error showing simple notification: $e');
    }
  }
}

// Firestore logging helper for Notification history
Future<void> _logNotificationHistory({
  required String status,
  String? medicineName,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .add({
          'medicineName': medicineName ?? 'Notification',
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    // Swallow errors to avoid breaking notification flow
    // Intentionally no rethrow
  }
}
