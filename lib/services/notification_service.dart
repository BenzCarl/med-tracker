// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
// Timezone plugin removed; relying on tzdata local
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize notifications with proper channel setup
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database (device local used by tz.local)
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

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

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

  /// Schedule weekly notifications at an exact time (Android exact alarms)
  static Future<void> scheduleWeeklyExact({
    required String tag,
    required String title,
    required String body,
    required int hour,
    required int minute,
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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: jsonEncode({
            'tag': tag,
            'medicineName': tag,
            'status': 'Reminder',
            'type': 'weekly_exact',
          }),
        );

        scheduledCount++;
        print(
          '📅 [EXACT] Scheduled notification for $tag on weekday $weekday at $hour:$minute',
        );
      }

      print('✅ [EXACT] Successfully scheduled $scheduledCount notifications for: $tag');
    } catch (e) {
      print('❌ Error scheduling EXACT notifications for $tag: $e');
      rethrow;
    }
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
          payload: jsonEncode({
            'tag': tag,
            'medicineName': tag,
            'status': 'Reminder',
            'type': 'weekly',
          }),
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
            payload: jsonEncode({
              'tag': tag,
              'medicineName': tag,
              'status': 'Reminder',
              'type': 'interval',
              'slot': i,
            }),
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

  /// Schedule multiple times per selected weekday using an hourly interval anchor (EXACT)
  static Future<void> scheduleIntervalWeeklyExact({
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
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: jsonEncode({
              'tag': tag,
              'medicineName': tag,
              'status': 'Reminder',
              'type': 'interval_exact',
              'slot': i,
            }),
          );

          print('📅 [EXACT] Interval schedule $tag weekday $weekday at $hour:$minute (slot $i)');
        }
      }

      print('✅ [EXACT] Interval weekly scheduling completed for: $tag');
    } catch (e) {
      print('❌ Error in EXACT interval weekly scheduling for $tag: $e');
      rethrow;
    }
  }

  /// Schedule notifications at minute intervals (EXACT) - for 2-minute reminders
  static Future<void> scheduleIntervalMinutesExact({
    required String tag,
    required String title,
    required String body,
    required int intervalMinutes,
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
        fullScreenIntent: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      
      // Limit to next 4 hours to avoid scheduling too many notifications at once
      final int hoursToSchedule = 4;
      final int notificationsToSchedule = (hoursToSchedule * 60 / intervalMinutes).floor();
      int scheduled = 0;

      for (int i = 0; i < notificationsToSchedule; i++) {
        final scheduledDate = now.add(Duration(minutes: intervalMinutes * (i + 1)));
        
        // Only schedule if the day is in the selected weekdays
        if (weekdays.isEmpty || weekdays.contains(scheduledDate.weekday)) {
          final id = (tag.hashCode.abs() % 900000) + i;

          await _notifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: jsonEncode({
              'tag': tag,
              'medicineName': tag,
              'status': 'Reminder',
              'type': 'interval_minutes_exact',
              'intervalMinutes': intervalMinutes,
            }),
          );

          scheduled++;
          if (i < 5 || i >= notificationsToSchedule - 2) {
            // Only print first 5 and last 2 to avoid log spam
            print('📅 [EXACT+FULLSCREEN] Scheduled for $tag on weekday ${scheduledDate.weekday} at ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}');
          }
        }
      }

      print('✅ [EXACT] Scheduled $scheduled minute-interval notifications for next $hoursToSchedule hours: $tag');
    } catch (e) {
      print('❌ Error scheduling EXACT minute-interval notifications for $tag: $e');
      rethrow;
    }
  }

  /// Schedule notifications at minute intervals (INEXACT) - for 2-minute reminders
  static Future<void> scheduleIntervalMinutes({
    required String tag,
    required String title,
    required String body,
    required int intervalMinutes,
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

      final now = tz.TZDateTime.now(tz.local);
      
      // Limit to next 4 hours to avoid scheduling too many notifications at once
      final int hoursToSchedule = 4;
      final int notificationsToSchedule = (hoursToSchedule * 60 / intervalMinutes).floor();
      int scheduled = 0;

      for (int i = 0; i < notificationsToSchedule; i++) {
        final scheduledDate = now.add(Duration(minutes: intervalMinutes * (i + 1)));
        
        // Only schedule if the day is in the selected weekdays
        if (weekdays.isEmpty || weekdays.contains(scheduledDate.weekday)) {
          final id = (tag.hashCode.abs() % 900000) + i;

          await _notifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: jsonEncode({
              'tag': tag,
              'medicineName': tag,
              'status': 'Reminder',
              'type': 'interval_minutes',
              'intervalMinutes': intervalMinutes,
            }),
          );

          scheduled++;
          if (i < 5 || i >= notificationsToSchedule - 2) {
            // Only print first 5 and last 2 to avoid log spam
            print('📅 Scheduled for $tag on weekday ${scheduledDate.weekday} at ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}');
          }
        }
      }

      print('✅ Scheduled $scheduled minute-interval notifications for next $hoursToSchedule hours: $tag');
    } catch (e) {
      print('❌ Error scheduling minute-interval notifications for $tag: $e');
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
        payload: jsonEncode({
          'tag': 'test',
          'medicineName': 'Test Reminder - Care Minder',
          'status': 'Test',
          'type': 'test',
        }),
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

      await _notifications.show(
        0,
        title,
        body,
        details,
        payload: jsonEncode({
          'tag': title,
          'medicineName': title,
          'status': 'Test',
          'type': 'instant',
        }),
      );
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

  /// Schedule notifications every minute for testing/development
  static Future<void> scheduleEveryMinute({
    required String tag,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      await requestPermissions();
      await requestExactAlarmsPermission();

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

      // Schedule 60 notifications for the next 60 minutes
      for (int i = 1; i <= 60; i++) {
        final now = tz.TZDateTime.now(tz.local);
        final scheduledDate = now.add(Duration(minutes: i));
        final id = (tag.hashCode.abs() % 900000) + i;

        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: jsonEncode({
            'tag': tag,
            'medicineName': tag,
            'status': 'Reminder',
            'type': 'every_minute',
            'minute': i,
          }),
        );
      }

      print('✅ [EVERY MINUTE] Scheduled 60 minute notifications for: $tag');
    } catch (e) {
      print('❌ Error scheduling every-minute notifications for $tag: $e');
      rethrow;
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
        payload: jsonEncode({
          'tag': tag,
          'medicineName': tag,
          'status': 'Reminder',
          'type': 'daily',
        }),
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

  /// Try to open system settings to enable Exact Alarms (Android 12/13+)
  static Future<void> openExactAlarmSettings() async {
    try {
      print('🔧 Opening Exact Alarm settings');
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    } catch (_) {
      try {
        // Fallback: open app notification settings
        const intent = AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        );
        await intent.launch();
      } catch (e) {
        // Final fallback: do nothing
      }
    }
  }

  // Removed system alarm fallback per requirement to use notifications only

  /// Cancel all pending notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('🗑️ All notifications cancelled');
  }

  /// Schedule a one-shot exact notification at the next occurrence of hour:minute
  /// across the provided weekdays (DateTime.monday..sunday). If weekdays is empty,
  /// schedules the next occurrence regardless of weekday.
  static Future<void> scheduleOneShotExactNext({
    required String tag,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays,
  }) async {
    try {
      await init();
      await requestPermissions();
      await requestExactAlarmsPermission();

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

      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      bool weekdayAllowed(int w) {
        if (weekdays.isEmpty) return true;
        return weekdays.contains(w);
      }

      // Find the nearest upcoming allowed day/time (within the next 14 days)
      int guard = 0;
      while ((candidate.isBefore(now) || !weekdayAllowed(candidate.weekday)) && guard < 14) {
        candidate = candidate.add(const Duration(days: 1));
        guard++;
      }

      // Unique ID: base hash plus minute precision timestamp suffix
      final base = tag.hashCode.abs() % 900000 + 100000; // 6-digit base
      final suffix = (candidate.millisecondsSinceEpoch ~/ 60000) % 1000; // minute bucket
      final id = base * 1000 + suffix;

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        candidate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({
          'tag': tag,
          'medicineName': tag,
          'status': 'Reminder',
          'type': 'oneshot_exact',
        }),
      );

      print('📌 One-shot EXACT scheduled for $tag at ' + candidate.toLocal().toString());
    } catch (e) {
      print('❌ Error scheduling one-shot exact for $tag: $e');
    }
  }

  /// Public helper to log to notification history
  static Future<void> logHistory({
    required String status,
    String? medicineName,
  }) async {
    await _logNotificationHistory(status: status, medicineName: medicineName);
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

// Foreground tap handler: log that user opened the notification
void _onNotificationResponse(NotificationResponse response) {
  try {
    final payload = response.payload;
    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final name = data['medicineName'] as String?;
    _logNotificationHistory(status: 'Opened', medicineName: name);
  } catch (_) {
    // ignore errors when logging
  }
}

/// Background tap handler must be a top-level function
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  try {
    final payload = response.payload;
    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final name = data['medicineName'] as String?;
    _logNotificationHistory(status: 'Opened', medicineName: name);
  } catch (_) {
    // ignore errors when logging
  }
}
