import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../login_screen.dart';
import 'attendance_screen.dart';
import 'budget_request_screen.dart';
import 'manager_report_screen.dart';
import '../../screens/owner/inventory_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final _db = FirebaseDatabase.instance.ref();
  Map<String, dynamic> dashboard = {};
  String managerName = 'Manager';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '🌤 Good Morning';
    if (h < 17) return '☀️ Good Afternoon';
    return '🌙 Good Evening';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final snap = await _db.child('dashboard').get();
    if (snap.exists) {
      setState(() => dashboard = Map<String, dynamic>.from(snap.value as Map));
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final mSnap = await _db.child('managers').get();
      if (mSnap.exists) {
        final managers = Map<String, dynamic>.from(mSnap.value as Map);
        for (final m in managers.values) {
          final data = Map<String, dynamic>.from(m as Map);
          if (data['uid'] == uid) {
            setState(() => managerName = data['name'] ?? 'Manager');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStats(),
            _buildModules(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SONA PEPCEE",
                style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
              Text("$_greeting, $managerName 👋",
                style: const TextStyle(color: Colors.white,
                  fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Role: MANAGER",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
              child: const Icon(Icons.logout, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _statChip('${dashboard['present'] ?? 0}', 'Present', Colors.green),
          const SizedBox(width: 10),
          _statChip('${dashboard['absent'] ?? 0}', 'Absent', Colors.red),
          const SizedBox(width: 10),
          _statChip('${dashboard['pendingOrders'] ?? 0}', 'Orders', Colors.blue),
          const SizedBox(width: 10),
          _statChip('${dashboard['lowStock'] ?? 0}', 'Low Stock', Colors.orange),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildModules(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _moduleCard(context, 'Mark Attendance', 'Check IN / OUT',
            Icons.fingerprint, Colors.green,
            const AttendanceScreen()),
          _moduleCard(context, 'Reports', 'View any worker',
            Icons.bar_chart, Colors.indigo,
            const ManagerReportScreen()),
          _moduleCard(context, 'Budget Request', 'Send to owner',
            Icons.request_quote, Colors.orange,
            const BudgetRequestScreen()),
          _moduleCard(context, 'Inventory', 'Manage stock',
            Icons.inventory_2_outlined, Colors.red,
            const InventoryScreen()),
        ],
      ),
    );
  }

  Widget _moduleCard(BuildContext context, String title, String sub,
    IconData icon, Color color, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
