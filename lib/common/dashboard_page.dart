import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../medicines/edit_medicine_page.dart';
import '../illness/add_illness_page.dart';
import '../medicines/add_medicine_page.dart';
import '../schedule/schedule_page.dart';
import '../inventory/inventory_page.dart';
import '../history/history_page.dart';
import '../profile/profile_page.dart';
import '../notification/notification_page.dart';
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
              ? "Care Minder"
              : _selectedIndex == 2
              ? "Care Minder"
              : "Care Minder",
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationPage(),
                ),
              );
            },
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
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  const Icon(Icons.info_outline, size: 16),
                                  Text("Dosage: ${med["dosage"] ?? ""}"),
                                ],
                              ),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  const Icon(Icons.local_hospital, size: 16),
                                  Text("Illness: ${med["illness"] ?? ""}"),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: FutureBuilder<QuerySnapshot>(
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
                                      return Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 16),
                                          const SizedBox(width: 4),
                                          const Expanded(
                                            child: Text("No schedule set"),
                                          ),
                                        ],
                                      );
                                    }
                                    final schedule =
                                        snapshot.data!.docs.first.data()
                                            as Map<String, dynamic>;
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.schedule, size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "Next Intake: ${schedule["time"] ?? ""} (${(schedule["days"] as List).join(", ")})",
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: FutureBuilder<QuerySnapshot>(
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
                                    final int initialStock = (() {
                                      final val = med["initialStock"];
                                      if (val is int) return val;
                                      if (val is String) return int.tryParse(val) ?? 0;
                                      if (val is double) return val.toInt();
                                      return 0;
                                    })();

                                    int purchasesSum = 0;
                                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                      purchasesSum = snapshot.data!.docs.fold<int>(0, (sum, doc) {
                                        final q = doc["quantity"];
                                        if (q is int) return sum + q;
                                        if (q is double) return sum + q.toInt();
                                        if (q is String) return sum + (int.tryParse(q) ?? 0);
                                        return sum;
                                      });
                                    }

                                    final int totalQuantity = initialStock + purchasesSum;

                                    if (totalQuantity <= 0) {
                                      return Row(
                                        children: const [
                                          Icon(Icons.inventory_2, size: 16),
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "No stock",
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else if (totalQuantity < 10) {
                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.inventory_2,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "Low stock: $totalQuantity",
                                              style: const TextStyle(
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.inventory_2,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "Stock left: $totalQuantity",
                                              style: const TextStyle(
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
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
