import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddMedicinePage extends StatefulWidget {
  const AddMedicinePage({super.key});

  @override
  State<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends State<AddMedicinePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _selectedFrequency;
  String? _selectedIllness;

  final List<String> _frequencies = ["Daily", "Weekly", "Monthly"];
  List<String> _illnesses = []; // fetched from Firebase

  @override
  void initState() {
    super.initState();
    _fetchIllnesses();
  }

  /// ✅ Fetch illnesses from Firestore (always as array)
  Future<void> _fetchIllnesses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data["illnesses"] != null) {
          setState(() {
            _illnesses = List<String>.from(data["illnesses"]);
          });
        } else {
          setState(() {
            _illnesses = [];
          });
        }
      }
    }
  }

  /// ✅ Date picker for start & end date
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat("yyyy/MM/dd").format(picked);
      });
    }
  }

  /// ✅ Save medicine into Firestore
  Future<void> _saveMedicine() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_nameController.text.isEmpty ||
          _dosageController.text.isEmpty ||
          _selectedFrequency == null ||
          _selectedIllness == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields")),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("medicines")
          .add({
            "name": _nameController.text,
            "dosage": _dosageController.text,
            "frequency": _selectedFrequency,
            "description": _descriptionController.text,
            "startDate": _startDateController.text,
            "endDate": _endDateController.text,
            "illness": _selectedIllness, // <-- illness is saved here
            "createdAt": FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicine added successfully")),
      );

      Navigator.pop(context); // go back after saving
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Medicine")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// Medicine Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Medicine Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            /// Dosage
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: "Dosage (e.g. 500mg, 1 tablet)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            /// Frequency Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Frequency",
                border: OutlineInputBorder(),
              ),
              value: _selectedFrequency,
              items: _frequencies
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedFrequency = value),
            ),
            const SizedBox(height: 16),

            /// Description
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            /// Start Date
            TextField(
              controller: _startDateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Start Date",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(_startDateController),
            ),
            const SizedBox(height: 16),

            /// End Date
            TextField(
              controller: _endDateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "End Date",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(_endDateController),
            ),
            const SizedBox(height: 16),

            /// Illness Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Illness",
                border: OutlineInputBorder(),
              ),
              value: _selectedIllness,
              items: _illnesses
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedIllness = value),
            ),
            const SizedBox(height: 24),

            /// Save Button
            ElevatedButton(
              onPressed: _saveMedicine,
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
