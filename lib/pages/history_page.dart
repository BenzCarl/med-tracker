import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: const [
          ListTile(
            title: Text("Paracetamol"),
            subtitle: Text("Taken at 08:00 AM"),
          ),
          ListTile(
            title: Text("Ibuprofen"),
            subtitle: Text("Missed at 06:00 PM"),
          ),
        ],
      ),
    );
  }
}
