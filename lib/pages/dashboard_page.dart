import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:med_tracker/pages/edit_medicine_page.dart';
import 'add_illness_page.dart';
import 'add_medicine_page.dart';
import 'schedule_page.dart';
import 'inventory_page.dart';
import 'history_page.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const SchedulePage(),
    const InventoryPage(),
    const HistoryPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _selectedIndex == 0
              ? "Home"
              : _selectedIndex == 1
              ? "Timetable"
              : _selectedIndex == 2
              ? "Inventory"
              : "Medication History",
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: "Timetable",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: "Inventory",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (user == null)
            const Expanded(
              child: Center(
                child: Text("Please log in to view your medicines."),
              ),
            )
          else ...[
            if (user.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user.photoURL!),
                radius: 40,
              ),
            const SizedBox(height: 10),
            Text(
              "Hello, ${user.displayName ?? "User"}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(user.email ?? ""),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddIllnessPage()),
                    );
                  },
                  icon: const Icon(Icons.local_hospital),
                  label: const Text("Add Illness"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddMedicinePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.medication),
                  label: const Text("Add Medicine"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
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
                    return const Center(child: Text("No medicines added yet"));
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Dosage: ${med["dosage"] ?? ""}"),
                              Text("Illness: ${med["illness"] ?? ""}"),
                              Text("Start: ${med["startDate"] ?? ""}"),
                              Text("End: ${med["endDate"] ?? ""}"),
                              FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(user.uid)
                                    .collection("schedules")
                                    .where(
                                      "medicineName",
                                      isEqualTo: med["name"],
                                    )
                                    .limit(1)
                                    .get(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return const Text("No schedule set");
                                  }
                                  final schedule =
                                      snapshot.data!.docs.first.data()
                                          as Map<String, dynamic>;
                                  return Text(
                                    "Next Intake: ${schedule["time"] ?? ""} (${(schedule["days"] as List).join(", ")})",
                                  );
                                },
                              ),
                              FutureBuilder<QuerySnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(user.uid)
                                    .collection("inventory")
                                    .where(
                                      "medicineName",
                                      isEqualTo: med["name"],
                                    )
                                    .get(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return const Text("No stock");
                                  }
                                  // Sum all quantities for this medicine
                                  int totalQuantity = snapshot.data!.docs
                                      .fold<int>(0, (sum, doc) {
                                        final q = doc["quantity"];
                                        if (q is int) return sum + q;
                                        if (q is double) return sum + q.toInt();
                                        if (q is String)
                                          return sum + (int.tryParse(q) ?? 0);
                                        return sum;
                                      });
                                  if (totalQuantity == 0) {
                                    return const Text(
                                      "No stock",
                                      style: TextStyle(color: Colors.red),
                                    );
                                  } else if (totalQuantity < 10) {
                                    return Text(
                                      "Low stock: $totalQuantity",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                      ),
                                    );
                                  } else {
                                    return Text(
                                      "Stock left: $totalQuantity",
                                      style: const TextStyle(
                                        color: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            final action = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Medicine Options"),
                                content: const Text(
                                  "Do you want to edit or delete this medicine?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, "edit"),
                                    child: const Text("Edit"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, "delete"),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, null),
                                    child: const Text("Cancel"),
                                  ),
                                ],
                              ),
                            );
                            if (action == "delete") {
                              // Delete medicine
                              await docs[index].reference.delete();
                              // Delete related schedules
                              final schedules = await FirebaseFirestore.instance
                                  .collection("users")
                                  .doc(user.uid)
                                  .collection("schedules")
                                  .where("medicineName", isEqualTo: med["name"])
                                  .get();
                              for (var doc in schedules.docs) {
                                await doc.reference.delete();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Medicine and schedule deleted",
                                  ),
                                ),
                              );
                            } else if (action == "edit") {
                              // Navigate to edit page (see below)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditMedicinePage(
                                    medicineDoc: docs[index],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
