import 'package:flutter/material.dart';
import 'add_illness_page.dart';
import 'add_medicine_page.dart';
import 'schedule_page.dart';
import 'inventory_page.dart';
import 'history_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Add Illness"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddIllnessPage()),
            ),
          ),
          ListTile(
            title: const Text("Add Medicine"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMedicinePage()),
            ),
          ),
          ListTile(
            title: const Text("Schedule Medication"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SchedulePage()),
            ),
          ),
          ListTile(
            title: const Text("Inventory"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryPage()),
            ),
          ),
          ListTile(
            title: const Text("History"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
        ],
      ),
    );
  }
}
