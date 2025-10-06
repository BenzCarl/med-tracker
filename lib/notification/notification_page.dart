import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to view notifications."));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Care Minder"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection(
              "history",
            ) // or "notifications" if you use a separate collection
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final medicine = data["medicineName"] ?? "Unknown";
              final status = data["status"] ?? "Reminder";
              final time = data["timestamp"] != null
                  ? (data["timestamp"] as Timestamp)
                        .toDate()
                        .toLocal()
                        .toString()
                  : "";
              return ListTile(
                leading: Icon(
                  status == "Taken"
                      ? Icons.check_circle
                      : status == "Missed"
                      ? Icons.cancel
                      : Icons.notifications,
                  color: status == "Taken"
                      ? Colors.green
                      : status == "Missed"
                      ? Colors.red
                      : Colors.blue,
                ),
                title: Text(medicine),
                subtitle: Text("$status at $time"),
              );
            },
          );
        },
      ),
    );
  }
}
