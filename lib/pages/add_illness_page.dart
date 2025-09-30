import 'package:flutter/material.dart';

class AddIllnessPage extends StatelessWidget {
  const AddIllnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Illness")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: "Enter")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () {}, child: const Text("Save Illness")),
          ],
        ),
      ),
    );
  }
}
