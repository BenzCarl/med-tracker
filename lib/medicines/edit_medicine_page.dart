import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditMedicinePage extends StatefulWidget {
  final QueryDocumentSnapshot medicineDoc;
  const EditMedicinePage({super.key, required this.medicineDoc});

  @override
  State<EditMedicinePage> createState() => _EditMedicinePageState();
}

class _EditMedicinePageState extends State<EditMedicinePage> {
  late TextEditingController nameController;
  late TextEditingController dosageController;
  late TextEditingController descriptionController;
  late TextEditingController startDateController;
  late TextEditingController endDateController;
  String? selectedIllness;
  String? selectedFrequency;

  // Schedule fields
  DocumentSnapshot? scheduleDoc;
  TimeOfDay? selectedTime;
  String selectedDays = "Weekdays";
  List<String> customDays = [];

  @override
  void initState() {
    super.initState();
    final med = widget.medicineDoc.data() as Map<String, dynamic>;
    nameController = TextEditingController(text: med["name"]);
    dosageController = TextEditingController(text: med["dosage"]);
    descriptionController = TextEditingController(text: med["description"]);
    startDateController = TextEditingController(text: med["startDate"]);
    endDateController = TextEditingController(text: med["endDate"]);
    selectedIllness = med["illness"];
    selectedFrequency = med["frequency"];
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("schedules")
        .where("medicineName", isEqualTo: nameController.text)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      setState(() {
        scheduleDoc = query.docs.first;
        final sched = scheduleDoc!.data() as Map<String, dynamic>;
        selectedTime = _parseTime(sched["time"]);
        if (sched["days"] != null && sched["days"] is List) {
          final days = List<String>.from(sched["days"]);
          if (days.length == 7) {
            selectedDays = "Custom";
            customDays = days;
          } else if (days.length == 5 && days.contains("Mon")) {
            selectedDays = "Weekdays";
          } else if (days.length == 2 && days.contains("Sat")) {
            selectedDays = "Weekends";
          } else {
            selectedDays = "Custom";
            customDays = days;
          }
        }
      });
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(RegExp(r'[: ]'));
    if (parts.length < 3) return null;
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    final isPM = parts[2].toUpperCase() == "PM";
    if (isPM && hour < 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // ⚡ Prepare update futures
    final medicineUpdateFuture = widget.medicineDoc.reference.update({
      "name": nameController.text,
      "dosage": dosageController.text,
      "description": descriptionController.text,
      "startDate": startDateController.text,
      "endDate": endDateController.text,
      "illness": selectedIllness,
      "frequency": selectedFrequency,
    });

    // If schedule exists, prepare schedule update
    Future<void>? scheduleUpdateFuture;
    if (scheduleDoc != null && selectedTime != null) {
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
      scheduleUpdateFuture = scheduleDoc!.reference.update({
        "medicineName": nameController.text,
        "dosage": dosageController.text,
        "time": selectedTime?.format(context),
        "days": daysToSave,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
    
    // ⚡ Run both updates in parallel
    if (scheduleUpdateFuture != null) {
      await Future.wait([medicineUpdateFuture, scheduleUpdateFuture]);
    } else {
      await medicineUpdateFuture;
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Medicine and schedule updated")),
    );
  }

  Future<void> _deleteMedicine() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Medicine"),
          content: const Text("Are you sure you want to delete this medicine? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        // Delete the medicine document
        await widget.medicineDoc.reference.delete();
        
        // Delete associated schedule if exists
        if (scheduleDoc != null) {
          await scheduleDoc!.reference.delete();
        }
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Medicine deleted successfully"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error deleting medicine: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Medicine"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteMedicine,
            tooltip: "Delete Medicine",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(labelText: "Dosage"),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
            const SizedBox(height: 8),
            // FIXED: Use proper interval codes matching add_medicine_page.dart
            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(labelText: "Frequency"),
              items: const [
                DropdownMenuItem(value: 'Daily', child: Text('Daily (once/day)')),
                DropdownMenuItem(value: 'q2m', child: Text('Every 2 minutes')),
                DropdownMenuItem(value: 'q2h', child: Text('Every 2 hours')),
                DropdownMenuItem(value: 'q4h', child: Text('Every 4 hours')),
                DropdownMenuItem(value: 'q6h', child: Text('Every 6 hours')),
                DropdownMenuItem(value: 'q12h', child: Text('Every 12 hours')),
              ],
              onChanged: (v) => setState(() => selectedFrequency = v),
            ),
            TextField(
              controller: startDateController,
              decoration: const InputDecoration(labelText: "Start Date"),
            ),
            TextField(
              controller: endDateController,
              decoration: const InputDecoration(labelText: "End Date"),
            ),
            // Add illness dropdown if needed
            const SizedBox(height: 20),
            if (scheduleDoc != null) ...[
              const Divider(),
              const Text(
                "Edit Schedule",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                title: Text(
                  selectedTime != null
                      ? "Time: ${selectedTime!.format(context)}"
                      : "Select Time",
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedDays,
                items: ["Weekdays", "Weekends", "Custom"]
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
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveChanges,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}