import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_dashboard.dart';
import 'worker_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isAdmin = true;
  bool isLoading = false;
  bool isSignupMode = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _saveUserProfile(User user) async {
    final role = isAdmin ? 'admin' : 'worker';
    final username = _usernameController.text.trim();
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'username': username,
      'role': role,
      'daysWorked': 0,
      'daysAbsent': 0,
      'totalHolidays': 0,
      'totalWorkingDays': 26,
      'hourlyWage': 80.0,
      'defaultDailyHours': 8,
      'deductions': 0.0,
      'lastCheckIn': '--:--',
      'phone': '',
      'department': 'Production',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveLoginEvent(User user) async {
    final role = isAdmin ? 'admin' : 'worker';
    await _firestore.collection('login_events').add({
      'uid': user.uid,
      'email': user.email,
      'role': role,
      'loggedInAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticateUser() async {
    String email = _emailController.text.trim();
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email & password")),
      );
      return;
    }

    if (isSignupMode && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (isSignupMode && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a username")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential credential;
      if (isSignupMode) {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final createdUser = credential.user;
        if (createdUser != null) {
          await createdUser.updateDisplayName(username);
          await _saveUserProfile(createdUser);
          await _saveLoginEvent(createdUser);
        }
      } else {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final loggedInUser = credential.user;
        if (loggedInUser != null) {
          await _firestore.collection('users').doc(loggedInUser.uid).set({
            'uid': loggedInUser.uid,
            'email': loggedInUser.email,
            'role': isAdmin ? 'admin' : 'worker',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await _saveLoginEvent(loggedInUser);
        }
      }

      if (!mounted) return;

      // 🔀 Navigate based on role
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isAdmin ? const AdminDashboard() : const WorkerDashboard(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = isSignupMode ? "Signup Failed" : "Login Failed";

      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password";
      } else if (e.code == 'email-already-in-use') {
        message = "Email already registered. Please login.";
      } else if (e.code == 'weak-password') {
        message = "Password should be at least 6 characters";
      } else if (e.code == 'invalid-email') {
        message = "Enter a valid email address";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FirebaseException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firestore save failed. Please try again.")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        isAdmin ? const Color(0xFF1B5E20) : const Color(0xFF3F51B5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(80),
                ),
              ),
              child: Center(
                child: Text(
                  isSignupMode
                      ? "Create\nAccount"
                      : isAdmin
                          ? "Admin\nManager"
                          : "Worker\nPortal",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  // 📧 EMAIL FIELD
                  if (isSignupMode) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔒 PASSWORD FIELD
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  if (isSignupMode) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Confirm Password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // 🔁 ROLE SWITCH
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Worker"),
                      Switch(
                        value: isAdmin,
                        onChanged: (value) {
                          setState(() => isAdmin = value);
                        },
                      ),
                      const Text("Admin"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🔘 LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: isLoading ? null : _authenticateUser,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isSignupMode ? "SIGN UP" : "LOGIN",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            setState(() {
                              isSignupMode = !isSignupMode;
                              _usernameController.clear();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          },
                    child: Text(
                      isSignupMode
                          ? "Already registered? Login"
                          : "No account? Sign up",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}