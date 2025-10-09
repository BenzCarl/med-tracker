// lib/pages/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import '../services/enhanced_notification_service.dart';
import '../common/dashboard_page.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  void _showScheduleDialog(
    BuildContext context,
    String medicineName,
    String dosage,
  ) {
    TimeOfDay? selectedTime;
    String selectedDays = "Weekdays";
    List<String> dayOptions = ["Weekdays", "Weekends", "Custom", "Daily"];
    List<String> customDays = [];
    String interval = "Daily"; // Daily, q2h, q4h, q6h, q12h

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _saveSchedule() async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || selectedTime == null) return;

              // Request notifications permission (Android 13+)
              await NotificationService.requestPermissions();

              // ✅ Prepare days (strings)
              List<String> daysToSave;
              if (selectedDays == "Custom") {
                daysToSave = List<String>.from(customDays);
              } else if (selectedDays == "Weekdays") {
                daysToSave = ["Mon", "Tue", "Wed", "Thu", "Fri"];
              } else if (selectedDays == "Weekends") {
                daysToSave = ["Sat", "Sun"];
              } else if (selectedDays == "Daily") {
                daysToSave = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
              } else {
                daysToSave = [];
              }

              // ✅ Save schedule to Firestore
              final query = await FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("schedules")
                  .where("medicineName", isEqualTo: medicineName)
                  .limit(1)
                  .get();

              if (query.docs.isNotEmpty) {
                await query.docs.first.reference.update({
                  "dosage": dosage,
                  "time": selectedTime?.format(context),
                  "days": daysToSave,
                  "interval": interval,
                  "createdAt": FieldValue.serverTimestamp(),
                });
              } else {
                await FirebaseFirestore.instance
                    .collection("users")
                    .doc(user.uid)
                    .collection("schedules")
                    .add({
                      "medicineName": medicineName,
                      "dosage": dosage,
                      "time": selectedTime?.format(context),
                      "days": daysToSave,
                      "interval": interval,
                      "createdAt": FieldValue.serverTimestamp(),
                    });
              }

              // ✅ Map days to weekday integers
              final dayMap = {
                "Mon": DateTime.monday,
                "Tue": DateTime.tuesday,
                "Wed": DateTime.wednesday,
                "Thu": DateTime.thursday,
                "Fri": DateTime.friday,
                "Sat": DateTime.saturday,
                "Sun": DateTime.sunday,
              };

              final weekdaysInts = daysToSave
                  .map((d) => dayMap[d] ?? 0)
                  .where((i) => i != 0)
                  .toList();

              // ✅ Cancel old notifications
              await NotificationService.cancelNotificationsForTag(medicineName);

              // ✅ Schedule new weekly notifications with exact time if possible
              if (weekdaysInts.isNotEmpty) {
                try {
                  if (interval == "q1m") {
                    // Every minute mode - for testing
                    final exactGranted = await NotificationService.requestExactAlarmsPermission();
                    if (exactGranted) {
                      await NotificationService.scheduleEveryMinute(
                        tag: medicineName,
                        title: "Take your $medicineName",
                        body: "Dosage: $dosage",
                      );
                      await EnhancedNotificationService.scheduleEveryMinute(
                        medicineName: medicineName,
                        dosage: dosage,
                      );
                    } else {
                      throw Exception('Exact alarm permission required for minute-based notifications');
                    }
                  } else if (interval == "Daily") {
                    // Try to request exact alarm permission for precise firing
                    final exactGranted = await NotificationService.requestExactAlarmsPermission();
                    // schedule once per selected day
                    if (exactGranted) {
                      await NotificationService.scheduleWeeklyExact(
                        tag: medicineName,
                        title: "Take your $medicineName",
                        body: "Dosage: $dosage",
                        hour: selectedTime!.hour,
                        minute: selectedTime!.minute,
                        weekdays: weekdaysInts,
                      );
                    } else {
                      await NotificationService.scheduleWeekly(
                        tag: medicineName,
                        title: "Take your $medicineName",
                        body: "Dosage: $dosage",
                        hour: selectedTime!.hour,
                        minute: selectedTime!.minute,
                        weekdays: weekdaysInts,
                      );
                    }
                    // Also schedule a one-shot immediate exact to ensure near-time reminders fire
                    await NotificationService.scheduleOneShotExactNext(
                      tag: medicineName,
                      title: "Take your $medicineName",
                      body: "Dosage: $dosage",
                      hour: selectedTime!.hour,
                      minute: selectedTime!.minute,
                      weekdays: weekdaysInts,
                    );
                  } else {
                    // For interval modes (excluding q1m), prefer exact scheduling when permission is granted
                    final exactGranted = await NotificationService.requestExactAlarmsPermission();
                    // map interval code
                    final intervalHours = interval == "q2h"
                        ? 2
                        : interval == "q4h"
                            ? 4
                            : interval == "q6h"
                                ? 6
                                : interval == "q12h"
                                    ? 12
                                    : 12;
                    if (exactGranted) {
                      await NotificationService.scheduleIntervalWeeklyExact(
                        tag: medicineName,
                        title: "Take your $medicineName",
                        body: "Dosage: $dosage",
                        anchorHour: selectedTime!.hour,
                        anchorMinute: selectedTime!.minute,
                        intervalHours: intervalHours,
                        weekdays: weekdaysInts,
                      );
                    } else {
                      await NotificationService.scheduleIntervalWeekly(
                        tag: medicineName,
                        title: "Take your $medicineName",
                        body: "Dosage: $dosage",
                        anchorHour: selectedTime!.hour,
                        anchorMinute: selectedTime!.minute,
                        intervalHours: intervalHours,
                        weekdays: weekdaysInts,
                      );
                    }
                    // Also schedule a one-shot immediate exact for the next upcoming slot today
                    await NotificationService.scheduleOneShotExactNext(
                      tag: medicineName,
                      title: "Take your $medicineName",
                      body: "Dosage: $dosage",
                      hour: selectedTime!.hour,
                      minute: selectedTime!.minute,
                      weekdays: weekdaysInts,
                    );
                  }

                  // Also use enhanced notification service for better Android 12-14 support
                  await EnhancedNotificationService.scheduleEnhancedReminder(
                    medicineName: medicineName,
                    dosage: dosage,
                    time: selectedTime!,
                    days: daysToSave,
                    interval: interval,
                    enableStockReduction: true,
                  );

                  // Show success message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("✅ Schedule saved for $medicineName"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Log to history as Scheduled so it appears in Notification page
                    await NotificationService.logHistory(
                      status: 'Scheduled',
                      medicineName: medicineName,
                    );
                  }

                  // Gentle battery optimization hint for Oppo/Android OEMs
                  if (context.mounted) {
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Improve reliability'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('For timely reminders:'),
                            SizedBox(height: 8),
                            Text('• Allow Autostart for Care Minder'),
                            Text('• Disable battery optimization for Care Minder'),
                            Text('• Enable Exact Alarms (Android 12/13+)'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  print("Error scheduling notifications: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "⚠️ Schedule saved but notification setup failed",
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    // Offer to open exact alarm settings if scheduling failed and might be due to missing permission
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Enable Exact Alarms'),
                        content: const Text(
                          'To ensure reminders fire exactly at the chosen time, please enable Exact Alarms in system settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await NotificationService.openExactAlarmSettings();
                            },
                            child: const Text('Open Settings'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "✅ Schedule saved (no days selected for notifications)",
                      ),
                    ),
                  );
                }
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.blue.shade50,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.purple.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Schedule Reminder",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$medicineName ($dosage)",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Time picker
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.access_time, color: Colors.blue.shade600),
                        title: Text(
                          selectedTime == null
                              ? "Select Time"
                              : "Time: ${selectedTime?.format(context)}",
                          style: TextStyle(
                            fontWeight: selectedTime != null ? FontWeight.bold : FontWeight.normal,
                            color: selectedTime != null ? Colors.blue.shade700 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) setState(() => selectedTime = picked);
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Day selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedDays,
                        items: dayOptions
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) {
                          setState(() => selectedDays = val ?? "Weekdays");
                        },
                        decoration: InputDecoration(
                          labelText: "Days",
                          prefixIcon: Icon(Icons.calendar_today, color: Colors.blue.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                  if (selectedDays == "Custom")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          "Select days:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var day in [
                              "Mon",
                              "Tue",
                              "Wed",
                              "Thu",
                              "Fri",
                              "Sat",
                              "Sun",
                            ])
                              FilterChip(
                                label: Text(day),
                                selected: customDays.contains(day),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      customDays.add(day);
                                    } else {
                                      customDays.remove(day);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                    // Interval selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: interval,
                        items: const [
                          DropdownMenuItem(value: 'Daily', child: Text('Daily (once/day)')),
                          DropdownMenuItem(value: 'q1m', child: Text('Every Minute (Testing)')),
                          DropdownMenuItem(value: 'q2h', child: Text('Every 2 hours')),
                          DropdownMenuItem(value: 'q4h', child: Text('Every 4 hours')),
                          DropdownMenuItem(value: 'q6h', child: Text('Every 6 hours')),
                          DropdownMenuItem(value: 'q12h', child: Text('Every 12 hours')),
                        ],
                        onChanged: (val) => setState(() => interval = val ?? 'Daily'),
                        decoration: InputDecoration(
                          labelText: 'Interval',
                          prefixIcon: Icon(Icons.repeat, color: Colors.blue.shade600),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: selectedTime != null
                            ? LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.purple.shade600,
                                ],
                              )
                            : null,
                        color: selectedTime == null ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: selectedTime != null
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: selectedTime == null ? null : _saveSchedule,
                          child: const Center(
                            child: Text(
                              "Save Schedule",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to view your medicines."));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.purple.shade600,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                    bottomRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const DashboardPage()),
                          (route) => false,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Schedule Reminders",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Test notification button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_active, color: Colors.white),
                        onPressed: () async {
                          await NotificationService.scheduleTestNotification();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Test notification scheduled for 10 seconds from now",
                              ),
                              backgroundColor: Colors.green.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        tooltip: "Test Notifications",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Test Notifications Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.teal.shade400,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.science_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Test Notifications",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Make sure notifications work before scheduling",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTestButton(
                              context,
                              "Instant",
                              Icons.flash_on_rounded,
                              Colors.green.shade600,
                              () async {
                                await NotificationService.showInstantNotification(
                                  title: "Test Instant Notification",
                                  body: "This is an instant test notification from Care Minder",
                                );
                                _showSuccessSnackBar(context, "Instant notification sent!");
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTestButton(
                              context,
                              "Scheduled",
                              Icons.schedule_rounded,
                              Colors.blue.shade600,
                              () async {
                                await NotificationService.scheduleTestNotification();
                                _showSuccessSnackBar(context, "Test scheduled for 10 seconds!");
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService.debugPendingNotifications();
                            _showSuccessSnackBar(context, "Check console for debug info");
                          },
                          icon: Icon(Icons.bug_report_rounded, color: Colors.purple.shade600),
                          label: Text(
                            "Debug Notifications",
                            style: TextStyle(color: Colors.purple.shade600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.purple.shade600),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.medication_rounded, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Your Medicines - Tap to Schedule",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Medicines List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(user.uid)
                      .collection("medicines")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            const Text("Error loading medicines"),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Trigger rebuild
                                (context as Element).markNeedsBuild();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medication_rounded,
                                size: 80,
                                color: Colors.blue.shade300,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "No Medicines Yet",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add medicines first to schedule reminders",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final med = docs[index].data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.blue.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _showScheduleDialog(
                                context,
                                med["name"] ?? "",
                                med["dosage"] ?? "",
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Medicine Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade400,
                                            Colors.purple.shade400,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.medication_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Medicine Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med["name"] ?? "Unknown Medicine",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.medical_information_rounded,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Dosage: ${med["dosage"] ?? "Not specified"}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "Tap to Schedule",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Arrow Icon
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey.shade400,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
