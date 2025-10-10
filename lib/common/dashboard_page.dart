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
import '../notification/active_notifications_page.dart';
import '../medicines/take_medicine_dialog.dart';
import '../services/notification_service.dart';
import '../analytics/analytics_page.dart';
import '../search/search_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  int _activeNotificationsCount = 0;
  Timer? _notificationCheckTimer;
  StreamSubscription<int>? _notificationCountSubscription;

  final List<Widget> _pages = [
    const HomeContent(),
    const SchedulePage(),
    const InventoryPage(),
    const HistoryPage(),
  ];

  @override
  void initState() {
    super.initState();
    _startLiveNotificationCount();
  }

  @override
  void dispose() {
    _notificationCheckTimer?.cancel();
    _notificationCountSubscription?.cancel();
    super.dispose();
  }

  void _startLiveNotificationCount() {
    // Use the live stream for real-time updates
    _notificationCountSubscription = NotificationService.getLiveNotificationCount().listen(
      (count) {
        if (mounted && count != _activeNotificationsCount) {
          setState(() {
            _activeNotificationsCount = count;
          });
          print('🔴 Live notification count updated: $count');
        }
      },
      onError: (error) {
        print('❌ Error in live notification stream: $error');
        // Fallback to timer-based checking
        _checkActiveNotifications();
        _notificationCheckTimer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => _checkActiveNotifications(),
        );
      },
    );
  }

  Future<void> _checkActiveNotifications() async {
    try {
      // Get ACTIVE notifications (currently showing in device notification tray)
      final count = await NotificationService.getActiveNotificationCount();
      if (mounted && count != _activeNotificationsCount) {
        setState(() {
          _activeNotificationsCount = count;
        });
        // Only print when count changes to reduce log spam
        print('🔴 Active notifications in tray: $count');
      }
    } catch (e) {
      print('Error checking active notifications: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showTestDialog(BuildContext context) async {
    // Get the first medicine from Firestore for testing
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final medicinesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .limit(1)
          .get();

      if (medicinesSnapshot.docs.isNotEmpty) {
        final medicine = medicinesSnapshot.docs.first.data();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TakeMedicineDialog(
              medicineName: medicine['name'] ?? 'Test Medicine',
              dosage: medicine['dosage'] ?? '1 tablet',
            ),
            fullscreenDialog: true,
          ),
        );
      } else {
        // No medicines found, show with dummy data
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TakeMedicineDialog(
              medicineName: 'Test Medicine',
              dosage: '1 tablet',
            ),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e) {
      print('Error showing test dialog: $e');
    }
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
          // LIVE Notification medicine icon - only shows when active notifications exist
          if (_activeNotificationsCount > 0)
            Stack(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ActiveNotificationsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.medication_liquid, color: Colors.green),
                  tooltip: 'Active Medicine Reminders (Live)',
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$_activeNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
            Colors.white,
          ],
        ),
      ),
      child: user == null
          ? const Center(
              child: Text("Please log in to view your medicines."),
            )
          : Column(
              children: [
                // Header Card with User Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.purple.shade600,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.blue.shade100,
                                backgroundImage: user.photoURL != null
                                    ? NetworkImage(user.photoURL!)
                                    : null,
                                child: user.photoURL == null
                                    ? Icon(
                                        Icons.person,
                                        size: 36,
                                        color: Colors.blue.shade700,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Welcome back,",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.displayName ?? "User",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: HomeContent._buildActionCard(
                                context,
                                Icons.local_hospital_rounded,
                                "Add Illness",
                                Colors.red,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddIllnessPage(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: HomeContent._buildActionCard(
                                context,
                                Icons.medication_rounded,
                                "Add Medicine",
                                Colors.green,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddMedicinePage(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Quick Access Features
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      HomeContent._buildQuickAction(
                        context,
                        Icons.analytics_rounded,
                        'Analytics',
                        Colors.blue,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                        ),
                      ),
                      HomeContent._buildQuickAction(
                        context,
                        Icons.search_rounded,
                        'Search',
                        Colors.green,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SearchPage()),
                        ),
                      ),
                      HomeContent._buildQuickAction(
                        context,
                        Icons.file_download_outlined,
                        'Reports',
                        Colors.orange,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsPage()),
                        ),
                      ),
                      HomeContent._buildQuickAction(
                        context,
                        Icons.settings_rounded,
                        'Settings',
                        Colors.purple,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Medicines Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.medication, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "My Medicines",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blue,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                              const SizedBox(height: 16),
                              const Text("Error loading medicines"),
                            ],
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.medication_rounded,
                                  size: 80,
                                  color: Colors.blue.shade300,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "No Medicines Yet",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap 'Add Medicine' to get started",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final med = docs[index].data();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white,
                                  Colors.blue.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditMedicinePage(
                                        medicineDoc: snapshot.data!.docs[index],
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue.shade400,
                                                  Colors.purple.shade400,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.medication_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  med["name"] ?? "Unknown",
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.medication, size: 14, color: Colors.grey.shade600),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      med["dosage"] ?? "No dosage",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey.shade400,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(color: Colors.grey.shade200),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.local_hospital, size: 16, color: Colors.red.shade400),
                                          const SizedBox(width: 8),
                                          Text(
                                            med["illness"] ?? "No illness",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
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

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: totalQuantity <= 0
                                                    ? Colors.red.shade50
                                                    : totalQuantity < 10
                                                        ? Colors.orange.shade50
                                                        : Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: totalQuantity <= 0
                                                      ? Colors.red.shade200
                                                      : totalQuantity < 10
                                                          ? Colors.orange.shade200
                                                          : Colors.green.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.inventory_2_rounded,
                                                    size: 16,
                                                    color: totalQuantity <= 0
                                                        ? Colors.red.shade700
                                                        : totalQuantity < 10
                                                            ? Colors.orange.shade700
                                                            : Colors.green.shade700,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    totalQuantity <= 0
                                                        ? "Out of stock"
                                                        : totalQuantity < 10
                                                            ? "Low: $totalQuantity left"
                                                            : "Stock: $totalQuantity",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: totalQuantity <= 0
                                                          ? Colors.red.shade700
                                                          : totalQuantity < 10
                                                              ? Colors.orange.shade700
                                                              : Colors.green.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}