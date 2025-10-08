// lib/pages/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
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
                  if (interval == "Daily") {
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
                    // For interval modes, prefer exact scheduling when permission is granted
                    final exactGranted = await NotificationService.requestExactAlarmsPermission();
                    // map interval code
                    final intervalHours = interval == "q2h"
                        ? 2
                        : interval == "q4h"
                            ? 4
                            : interval == "q6h"
                                ? 6
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

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Schedule for $medicineName ($dosage)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // time picker
                  ListTile(
                    title: Text(
                      selectedTime == null
                          ? "Select Time"
                          : "Time: ${selectedTime?.format(context)}",
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => selectedTime = picked);
                    },
                  ),

                  const SizedBox(height: 8),

                  // day selector
                  DropdownButtonFormField<String>(
                    value: selectedDays,
                    items: dayOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedDays = val ?? "Weekdays");
                    },
                    decoration: const InputDecoration(
                      labelText: "Days",
                      border: OutlineInputBorder(),
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

                  // interval selector (overrides medicine frequency)
                  DropdownButtonFormField<String>(
                    value: interval,
                    items: const [
                      DropdownMenuItem(value: 'Daily', child: Text('Daily (once/day)')),
                      DropdownMenuItem(value: 'q2h', child: Text('Every 2 hours')),
                      DropdownMenuItem(value: 'q4h', child: Text('Every 4 hours')),
                      DropdownMenuItem(value: 'q6h', child: Text('Every 6 hours')),
                      DropdownMenuItem(value: 'q12h', child: Text('Every 12 hours')),
                    ],
                    onChanged: (val) => setState(() => interval = val ?? 'Daily'),
                    decoration: const InputDecoration(
                      labelText: 'Interval',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedTime == null
                              ? null
                              : _saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Save Schedule"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                ],
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
      appBar: AppBar(
        title: const Text("Schedule Reminders"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () async {
              await NotificationService.scheduleTestNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Test notification scheduled for 10 seconds from now",
                  ),
                ),
              );
            },
            tooltip: "Test Notifications",
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
          );
          return false;
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Test Notifications Button
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        "Test Notifications",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Make sure notifications are working before setting up reminders",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await NotificationService.showInstantNotification(
                                  title: "Test Instant Notification",
                                  body:
                                      "This is an instant test notification from Care Minder",
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Instant notification sent!"),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Instant Test"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await NotificationService.scheduleTestNotification();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Scheduled test notification for 10 seconds from now",
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Scheduled Test"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await NotificationService.debugPendingNotifications();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Check console for pending notifications",
                              ),
                            ),
                          );
                        },
                        child: const Text("Debug Notifications"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Your Medicines - Tap to Schedule",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              const SizedBox(height: 16),

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
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text("Error loading medicines"),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // Retry loading
                              },
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No medicines found",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Add medicines first to schedule reminders",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final med = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: const Icon(
                              Icons.medication,
                              color: Colors.blue,
                            ),
                            title: Text(
                              med["name"] ?? "Unknown Medicine",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Dosage: ${med["dosage"] ?? "Not specified"}",
                            ),
                            // trailing icon removed per request
                            onTap: () => _showScheduleDialog(
                              context,
                              med["name"] ?? "",
                              med["dosage"] ?? "",
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
}
