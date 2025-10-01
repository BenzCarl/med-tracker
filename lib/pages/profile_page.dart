import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>?> _getUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();
    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No profile data found"));
          }

          final userData = snapshot.data!;
          final illnesses = (userData["illnesses"] as List?)?.join(", ") ?? "";

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Name",
                    hintText:
                        "${userData["firstName"] ?? ""} ${userData["lastName"] ?? ""}",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Email",
                    hintText: userData["email"] ?? "",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Contact",
                    hintText: userData["contact"] ?? "",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Illness",
                    hintText: illnesses,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
