import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import '../common/dashboard_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController middleInitialController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  DateTime? _selectedDob;
  bool _loading = false;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    middleInitialController.dispose();
    emailController.dispose();
    contactController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  void _showSnackBar(String message, {bool error = false}) {
    final snack = SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: error ? Colors.red : Colors.green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snack);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _register() async {
    // Basic validation
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final middleInitial = middleInitialController.text.trim();
    final email = emailController.text.trim();
    final contact = contactController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty) {
      _showSnackBar("Please enter first and last name", error: true);
      return;
    }
    if (email.isEmpty) {
      _showSnackBar("Please enter email", error: true);
      return;
    }
    if (_selectedDob == null) {
      _showSnackBar("Please select date of birth", error: true);
      return;
    }
    if (contact.isEmpty) {
      _showSnackBar("Please enter contact number", error: true);
      return;
    }
    if (password.isEmpty || confirm.isEmpty) {
      _showSnackBar("Please enter password and confirm it", error: true);
      return;
    }
    if (password != confirm) {
      _showSnackBar("Passwords do not match", error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      // Create the auth user (this signs the user in)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'UNKNOWN',
          message: 'No user returned',
        );
      }

      // Update display name in Firebase Auth
      final displayName = "$firstName ${lastName}";
      await user.updateDisplayName(displayName);

      // Prepare user profile data
      final age = _calculateAge(_selectedDob!);
      final userDoc = {
        'firstName': firstName,
        'lastName': lastName,
        'middleInitial': middleInitial,
        'dob': Timestamp.fromDate(_selectedDob!),
        'age': age,
        'contact': contact,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore under users/{uid}
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userDoc);

      _showSnackBar("Registration successful!");

      // Navigate to Dashboard (user is already signed-in)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Registration failed", error: true);
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildInput(
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageText = _selectedDob == null
        ? ''
        : _calculateAge(_selectedDob!).toString();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Names row
                    Row(
                      children: [
                        Expanded(
                          child: _buildInput("First name", firstNameController),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildInput("Last name", lastNameController),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: _buildInput("M.I.", middleInitialController),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // DOB + Age
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDob,
                            child: AbsorbPointer(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: _selectedDob == null
                                      ? "Date of Birth"
                                      : "${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: ageText.isEmpty ? "Age" : ageText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 12,
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    _buildInput(
                      "Contact Number",
                      contactController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                      "Email",
                      emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                      "Password",
                      passwordController,
                      isPassword: true,
                    ),
                    const SizedBox(height: 8),
                    _buildInput(
                      "Confirm Password",
                      confirmPasswordController,
                      isPassword: true,
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Register",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}
