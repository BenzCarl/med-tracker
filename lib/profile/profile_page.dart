import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../illness/add_illness_page.dart';

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
  List<String> _illnesses = [];

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
            _illnesses = List<String>.from(illnesses.map((e) => e.toString()));
          } else {
            _illnessController.text = "";
            _illnesses = [];
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

  Future<void> _renameIllness(String oldName) async {
    final controller = TextEditingController(text: oldName);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Illness"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "New name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;

    // Update illnesses array
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'illnesses': FieldValue.arrayRemove([oldName]),
    }, SetOptions(merge: true));
    await userRef.set({
      'illnesses': FieldValue.arrayUnion([newName]),
    }, SetOptions(merge: true));

    // Ask to propagate rename to medicines
    final propagate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Update Medicines?"),
        content: Text(
          "Do you want to update medicines referencing '$oldName' to '$newName'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (propagate == true) {
      final meds = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .where('illness', isEqualTo: oldName)
          .get();
      for (final doc in meds.docs) {
        await doc.reference.update({'illness': newName});
      }
    }

    await _loadUserData();
  }

  Future<void> _deleteIllness(String illness) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Illness"),
        content: const Text(
          "Deleting an illness won't delete medicines. You can also clear this illness from medicines.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete_only'),
            child: const Text("Delete Only"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'delete_and_clear'),
            child: const Text("Delete and Clear from Medicines"),
          ),
        ],
      ),
    );

    if (choice == null || choice == 'cancel') return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'illnesses': FieldValue.arrayRemove([illness]),
    }, SetOptions(merge: true));

    if (choice == 'delete_and_clear') {
      final meds = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .where('illness', isEqualTo: illness)
          .get();
      for (final doc in meds.docs) {
        await doc.reference.update({'illness': FieldValue.delete()});
      }
    }

    await _loadUserData();
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
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.pink.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade600,
                      Colors.pink.shade600,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        // Edit / Save button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isEditing ? Icons.check_circle : Icons.edit,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_isEditing) {
                                  _saveProfile();
                                }
                                _isEditing = !_isEditing;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Add illness button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddIllnessPage()),
                              ).then((_) {
                                _loadUserData();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Profile Avatar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.purple.shade100,
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.purple.shade700,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isEmpty ? "User Profile" : _nameController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(Icons.person, "Name", _nameController, editable: _isEditing),
                    _buildInfoCard(Icons.email, "Email", _emailController, editable: _isEditing),
                    _buildInfoCard(Icons.phone, "Contact", _contactController, editable: _isEditing),
                    _buildDateCard(),
                    _buildInfoCard(Icons.cake, "Age", _ageController),
                    _buildInfoCard(Icons.local_hospital, "Illness", _illnessController),

                    const SizedBox(height: 20),

                    // Illness management list
                    if (_illnesses.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white,
                              Colors.pink.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.health_and_safety, color: Colors.purple.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  "Manage Illnesses",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._illnesses.map((i) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.purple.shade200),
                                  ),
                                  child: ListTile(
                                    leading: Icon(Icons.medical_services, color: Colors.purple.shade600),
                                    title: Text(
                                      i,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit, color: Colors.blue.shade600),
                                          onPressed: () => _renameIllness(i),
                                          tooltip: 'Rename',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteIllness(i),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    
                    // Change Password Button
                    Center(
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade600,
                              Colors.pink.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _showChangePasswordDialog,
                          child: const Text(
                            "Change Password",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, TextEditingController controller, {bool editable = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: !editable,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.purple.shade600),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.purple.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.purple.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _pickDate,
        child: AbsorbPointer(
          child: TextField(
            controller: _dobController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: "Date of Birth",
              prefixIcon: Icon(Icons.calendar_today, color: Colors.purple.shade600),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.purple.shade200),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
