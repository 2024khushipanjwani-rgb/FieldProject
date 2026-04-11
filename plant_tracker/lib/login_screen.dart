import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/worker/worker_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseDatabase.instance.ref();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '🌤 Good Morning';
    if (h < 17) return '☀️ Good Afternoon';
    return '🌙 Good Evening';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getRoleFromDatabase(String uid, String email) async {
    // Check owners
    final ownersSnap = await _db.child('owners').get();
    if (ownersSnap.exists) {
      final owners = Map<String, dynamic>.from(ownersSnap.value as Map);
      for (final entry in owners.entries) {
        final o = Map<String, dynamic>.from(entry.value as Map);
        if (o['uid'] == uid) return 'admin';
      }
    }
    // Check managers
    final managersSnap = await _db.child('managers').get();
    if (managersSnap.exists) {
      final managers = Map<String, dynamic>.from(managersSnap.value as Map);
      for (final entry in managers.entries) {
        final m = Map<String, dynamic>.from(entry.value as Map);
        if (m['uid'] == uid) return 'manager';
      }
    }
    // Check workers
    final workersSnap = await _db.child('workers').get();
    if (workersSnap.exists) {
      final workers = Map<String, dynamic>.from(workersSnap.value as Map);
      for (final entry in workers.entries) {
        final w = Map<String, dynamic>.from(entry.value as Map);
        if (w['uid'] == uid) return 'worker';
      }
    }
    return null;
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')));
      return;
    }
    setState(() => isLoading = true);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = credential.user;
      if (user == null) return;

      final role = await _getRoleFromDatabase(user.uid, user.email ?? '');
      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const OwnerDashboard()));
      } else if (role == 'manager') {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ManagerDashboard()));
      } else if (role == 'worker') {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const WorkerDashboard()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Contact your owner.')));
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'No account found';
      if (e.code == 'wrong-password') msg = 'Incorrect password';
      if (e.code == 'invalid-email') msg = 'Invalid email';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() => isLoading = false);
  }

  void _quickAccess(String role) {
    if (role == 'admin') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboard()));
    } else if (role == 'manager') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerDashboard()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerDashboard()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              height: 280,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(80),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting,
                      style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text("SONA PEPCEE",
                      style: TextStyle(color: Colors.white,
                        fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Field Project Management",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('LOGIN',
                            style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 35),
                  // Quick Access
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        const Text('⚡ Quick Access (Demo)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Explore without login',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            _quickBtn('Owner', Icons.person, Colors.indigo, () => _quickAccess('admin')),
                            const SizedBox(width: 8),
                            _quickBtn('Manager', Icons.manage_accounts, Colors.orange, () => _quickAccess('manager')),
                            const SizedBox(width: 8),
                            _quickBtn('Worker', Icons.engineering, Colors.green, () => _quickAccess('worker')),
                          ],
                        ),
                      ],
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

  Widget _quickBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color,
                fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
