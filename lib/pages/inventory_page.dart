import 'package:flutter/material.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      body: ListView(
        children: const [
          ListTile(
            title: Text("Paracetamol - 20 tablets"),
            subtitle: Text("Stock added on 2025-09-30"),
          ),
        ],
      ),
    );
  }
}
