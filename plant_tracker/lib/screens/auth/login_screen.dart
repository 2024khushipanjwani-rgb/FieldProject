import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plant_tracker/screens/manager/admin_dashboard.dart';
import 'package:plant_tracker/screens/worker/worker_dashboard.dart';
import 'package:plant_tracker/core/app_roles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Selected account type for login / signup.
  int _roleIndex = 0; // 0 worker, 1 manager, 2 owner

  bool isLoading = false;
  bool isSignupMode = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _secretKeyController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _selectedRole {
    switch (_roleIndex) {
      case 1:
        return AppRoles.manager;
      case 2:
        return AppRoles.owner;
      default:
        return AppRoles.worker;
    }
  }

  Color get _primaryColor {
    switch (_roleIndex) {
      case 1:
        return const Color(0xFF1B5E20);
      case 2:
        return const Color(0xFF0D47A1);
      default:
        return const Color(0xFF3F51B5);
    }
  }

  Future<void> _saveUserProfile(User user) async {
    final username = _usernameController.text.trim();
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'username': username,
      'role': _selectedRole,
      'daysWorked': 0,
      'daysAbsent': 0,
      'totalHolidays': 0,
      'totalWorkingDays': 26,
      'hourlyWage': 80.0,
      'defaultDailyHours': 8,
      'deductions': 0.0,
      'lastCheckIn': '--:--',
      'phone': '',
      'department': _selectedRole == AppRoles.worker
          ? 'Production'
          : (_selectedRole == AppRoles.manager ? 'Management' : 'Owner'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveLoginEvent(User user, String role) async {
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
    _secretKeyController.dispose();
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
      if (isSignupMode && _roleIndex > 0) {
        final secretInput = _secretKeyController.text.trim();
        if (secretInput.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Secret key required for this role.")),
          );
          setState(() => isLoading = false);
          return;
        }

        final secretsDoc = await _firestore.collection('system_config').doc('secrets').get();
        final data = secretsDoc.data() ?? {};
        final requiredKey = _roleIndex == 1 ? data['manager_key'] : data['owner_key'];
        
        if (requiredKey == null || secretInput != requiredKey) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid Secret Key!")),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      UserCredential credential;
      String? loginStoredRole;
      if (isSignupMode) {
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final createdUser = credential.user;
        if (createdUser != null) {
          await createdUser.updateDisplayName(username);
          await _saveUserProfile(createdUser);
          await _saveLoginEvent(createdUser, _selectedRole);
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
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          final profile = await _firestore
              .collection('users')
              .doc(loggedInUser.uid)
              .get();
          loginStoredRole =
              (profile.data()?['role'] as String?) ?? AppRoles.worker;
          await _saveLoginEvent(
            loggedInUser,
            loginStoredRole ?? AppRoles.worker,
          );
        }
      }

      if (!mounted) return;

      Widget destination = const WorkerDashboard();
      if (!isSignupMode) {
        final stored = loginStoredRole;
        if (stored != null && isStaffRole(stored)) {
          destination = const AdminDashboard();
        } else {
          destination = const WorkerDashboard();
        }
      } else {
        destination = _roleIndex == 0
            ? const WorkerDashboard()
            : const AdminDashboard();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
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
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Firestore Error: ${e.message ?? 'Unknown'}")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isSignupMode ? _primaryColor : const Color(0xFF3F51B5);

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
                  isSignupMode ? "Create\nAccount" : "Welcome\nBack",
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

                  const SizedBox(height: 24),

                  if (isSignupMode) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Account type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('Worker'),
                          icon: Icon(Icons.engineering, size: 18),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Manager'),
                          icon: Icon(Icons.supervisor_account, size: 18),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('Owner'),
                          icon: Icon(Icons.business, size: 18),
                        ),
                      ],
                      selected: {_roleIndex},
                      onSelectionChanged: (s) {
                        setState(() => _roleIndex = s.first);
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_roleIndex > 0) ...[
                      TextField(
                        controller: _secretKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Role Secret Key",
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ] else ...[
                    Text(
                      'You will open the dashboard for the role saved on your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),
                  ],

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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
                              _secretKeyController.clear();
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