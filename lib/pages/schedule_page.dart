import 'package:flutter/material.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: "Time (e.g., 08:00 AM)"),
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: "Days (e.g., Daily, Mon/Wed)",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Save Schedule"),
            ),
          ],
        ),
      ),
    );
  }
}
