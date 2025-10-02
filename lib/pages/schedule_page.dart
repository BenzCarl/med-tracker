import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  void _showScheduleDialog(
    BuildContext context,
    String medicineName,
    String dosage,
  ) {
    TimeOfDay? selectedTime;
    String selectedDays = "Weekdays";
    List<String> dayOptions = ["Weekdays", "Weekends", "Custom"];
    List<String> customDays = [];

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Schedule for $medicineName ($dosage)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
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
                  DropdownButtonFormField<String>(
                    value: selectedDays,
                    items: dayOptions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (val) {
                      setState(() => selectedDays = val ?? "Weekdays");
                    },
                    decoration: const InputDecoration(labelText: "Days"),
                  ),
                  if (selectedDays == "Custom")
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || selectedTime == null) return;

                      // Prepare days
                      List<String> daysToSave;
                      if (selectedDays == "Custom") {
                        daysToSave = List<String>.from(customDays);
                      } else if (selectedDays == "Weekdays") {
                        daysToSave = ["Mon", "Tue", "Wed", "Thu", "Fri"];
                      } else if (selectedDays == "Weekends") {
                        daysToSave = ["Sat", "Sun"];
                      } else {
                        daysToSave = [];
                      }

                      // Check if a schedule already exists for this medicine
                      final query = await FirebaseFirestore.instance
                          .collection("users")
                          .doc(user.uid)
                          .collection("schedules")
                          .where("medicineName", isEqualTo: medicineName)
                          .limit(1)
                          .get();

                      if (query.docs.isNotEmpty) {
                        // Update existing schedule
                        await query.docs.first.reference.update({
                          "dosage": dosage,
                          "time": selectedTime?.format(context),
                          "days": daysToSave,
                          "createdAt": FieldValue.serverTimestamp(),
                        });
                      } else {
                        // Create new schedule
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(user.uid)
                            .collection("schedules")
                            .add({
                              "medicineName": medicineName,
                              "dosage": dosage,
                              "time": selectedTime?.format(context),
                              "days": daysToSave,
                              "createdAt": FieldValue.serverTimestamp(),
                            });
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Schedule saved for $medicineName"),
                        ),
                      );
                    },
                    child: const Text("Save Schedule"),
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
      // Remove or set appBar to null
      appBar: null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder(
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
              return const Center(child: Text("Error loading medicines"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No medicines found"));
            }

            final docs = snapshot.data!.docs;
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final med = docs[index].data();
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(med["name"] ?? ""),
                    subtitle: Text("Dosage: ${med["dosage"] ?? ""}"),
                    trailing: const Icon(Icons.schedule),
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
    );
  }
}
