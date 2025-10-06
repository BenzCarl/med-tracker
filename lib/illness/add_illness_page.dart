import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddIllnessPage extends StatefulWidget {
  const AddIllnessPage({super.key});

  @override
  State<AddIllnessPage> createState() => _AddIllnessPageState();
}

class _AddIllnessPageState extends State<AddIllnessPage> {
  final TextEditingController illnessController = TextEditingController();

  Future<void> _addIllness() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || illnessController.text.trim().isEmpty) return;

    final illness = illnessController.text.trim();

    // ✅ Save illness to Firestore under illnesses array
    await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
      "illnesses": FieldValue.arrayUnion([illness]),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Illness successfully added!")),
    );

    Navigator.pop(context); // go back to ProfilePage
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Illness"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: illnessController,
              decoration: const InputDecoration(
                labelText: "Illness",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _addIllness, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }
}
