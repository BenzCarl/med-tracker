import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:med_tracker/pages/add_illness_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _illnessController = TextEditingController();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();

      if (data != null) {
        setState(() {
          _nameController.text =
              "${data['firstName']} ${data['middleInitial']} ${data['lastName']}";
          _emailController.text = data['email'] ?? '';
          _contactController.text = data['contact'] ?? '';

          // ✅ Fix illness field (use array from Firestore)
          if (data['illnesses'] != null) {
            List<dynamic> illnesses = data['illnesses'];
            _illnessController.text = illnesses.join(", ");
          } else {
            _illnessController.text = "";
          }

          // ✅ DOB from Firestore
          if (data['dob'] != null) {
            DateTime dob;
            if (data['dob'] is Timestamp) {
              dob = (data['dob'] as Timestamp).toDate();
            } else if (data['dob'] is String) {
              dob = DateTime.parse(data['dob']);
            } else {
              dob = DateTime.now();
            }

            _dobController.text = DateFormat('yyyy-MM-dd').format(dob);

            // ✅ Calculate and show age
            int age = DateTime.now().year - dob.year;
            if (DateTime.now().month < dob.month ||
                (DateTime.now().month == dob.month &&
                    DateTime.now().day < dob.day)) {
              age--;
            }
            _ageController.text = age.toString();
          }
        });
      }
    }
  }

  void _pickDate() async {
    if (!_isEditing) return; // prevent editing if not in edit mode

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);

        // Update age automatically
        int age = DateTime.now().year - picked.year;
        if (DateTime.now().month < picked.month ||
            (DateTime.now().month == picked.month &&
                DateTime.now().day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
    }
  }

  void _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          "firstName": _nameController.text.split(" ").first,
          "lastName": _nameController.text.split(" ").length > 1
              ? _nameController.text.split(" ").last
              : "",
          "email": _emailController.text,
          "contact": _contactController.text,
          // 🚫 Removed illness here so we don’t overwrite it
          "dob": _dobController.text,
          "age": int.tryParse(_ageController.text) ?? 0,
          "updatedAt": FieldValue.serverTimestamp(),
        },
      );
    }
  }

  void _showChangePasswordDialog() {
    final TextEditingController oldPass = TextEditingController();
    final TextEditingController newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPass,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Old Password"),
            ),
            TextField(
              controller: newPass,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                User user = FirebaseAuth.instance.currentUser!;
                AuthCredential credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: oldPass.text,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPass.text);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password updated successfully"),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Edit / Save button
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _saveProfile(); // ✅ save before turning off edit mode
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          // ➕ Add illness button
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddIllnessPage()),
              ).then((_) {
                _loadUserData(); // ✅ refresh illnesses when coming back
              });
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              readOnly: !_isEditing,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              readOnly: _isEditing,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _contactController,
              readOnly: !_isEditing,
              decoration: const InputDecoration(
                labelText: "Contact",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: _dobController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Date of Birth",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ageController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Age",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _illnessController,
              readOnly: true, // ✅ Illness cannot be edited
              decoration: const InputDecoration(
                labelText: "Illness",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _showChangePasswordDialog,
                child: const Text("Change Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
