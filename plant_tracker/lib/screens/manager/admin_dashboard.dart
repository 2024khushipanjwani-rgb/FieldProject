import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plant_tracker/screens/manager/attendance_screen.dart';
import 'package:plant_tracker/screens/manager/inventory_screen.dart';
import 'package:plant_tracker/screens/worker/salary_screen.dart';
import 'package:plant_tracker/screens/manager/orders_screen.dart';
import 'package:plant_tracker/screens/owner/notification_screen.dart';
import 'package:plant_tracker/screens/auth/login_screen.dart';
import 'package:plant_tracker/screens/worker/workers_screen.dart';
import 'package:plant_tracker/core/app_roles.dart';
import 'package:plant_tracker/screens/manager/staff_weekly_overview_screen.dart';
import 'package:plant_tracker/screens/manager/funding_request_screen.dart';
import 'package:plant_tracker/screens/owner/owner_funding_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>> _currentUserStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  bool _isOwner(String? role) => isOwnerRole(role);

  bool _isManager(String? role) => isManagerRole(role);

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      return "Good Evening";
    } else {
      return "Hello";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFigmaHeader(context),
            _buildSectionTitle("MANAGEMENT MODULES"),
            _buildModuleGrid(context),
            _buildSectionTitle("RECENT ACTIVITY"),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _currentUserStream(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  final username = (data?['username'] as String?)?.trim();
                  final role = (data?['role'] as String?) ?? AppRoles.legacyAdmin;
                  final displayName = (username != null && username.isNotEmpty)
                      ? username
                      : (role == AppRoles.manager
                          ? "Manager"
                          : "Owner");
                  final roleLabel = role == AppRoles.legacyAdmin
                      ? "OWNER"
                      : role.toUpperCase();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SONA PEPCEE",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              letterSpacing: 1.2)),
                      Text("${_getGreeting()}, $displayName 👋",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text("Role: $roleLabel",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  );
                },
              ),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _currentUserStream(),
                builder: (context, snapshot) {
                  final role = snapshot.data?.data()?['role'] as String?;
                  final ownerAccount = _isOwner(role);
                  return Row(
                    children: [
                      _headerIcon(
                        icon: Icons.notifications_none,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationScreen(
                                collectionPath: ownerAccount
                                    ? 'owner_notifications'
                                    : 'admin_notifications',
                                screenTitle: ownerAccount
                                    ? 'Owner alerts'
                                    : 'Team alerts',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _headerIcon(
                        icon: Icons.logout,
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _topStatusChip("—", "Present"),
              _topStatusChip("—", "Pending"),
              _topStatusChip("—", "Done"),
              _topStatusChip("—", "Stock"),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerIcon({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _topStatusChip(String count, String label) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(count,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 15),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.1)),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _currentUserStream(),
      builder: (context, snapshot) {
        final role = snapshot.data?.data()?['role'] as String?;
        final ownerAccount = _isOwner(role);
        final managerAccount = _isManager(role);

        final cards = <Widget>[
          _moduleCard(context, "Attendance", "Today’s board",
              Icons.calendar_today, Colors.green, const AttendanceScreen()),
          _moduleCard(context, "Workers", "Mark in / out",
              Icons.groups_2_outlined, Colors.indigo, const WorkersScreen()),
          _moduleCard(
            context,
            "Team report",
            "Wages & attendance",
            Icons.analytics_outlined,
            Colors.teal,
            const StaffWeeklyOverviewScreen(),
          ),
        ];

        if (managerAccount) {
          cards.add(
            _moduleCard(
              context,
              "Request funds",
              "Ask the owner",
              Icons.payments_outlined,
              Colors.deepPurple,
              const FundingRequestScreen(),
            ),
          );
        }

        if (ownerAccount) {
          cards.addAll([
            _moduleCard(
              context,
              "Fund requests",
              "Approve / deny",
              Icons.approval,
              Colors.brown,
              const OwnerFundingScreen(),
            ),
            _moduleCard(context, "Payroll / payslips", "All workers",
                Icons.attach_money, Colors.orange, const SalaryScreen()),
            _moduleCard(context, "Inventory", "Stock management",
                Icons.inventory_2_outlined, Colors.red, const InventoryScreen()),
            _moduleCard(context, "Orders", "Track shipments",
                Icons.assignment_outlined, Colors.purple, const OrdersScreen()),
          ]);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _moduleCard(BuildContext context, String title, String sub,
      IconData icon, Color color, Widget page) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sub,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _activityTile("Manager marked attendance — check Owner alerts",
              "Live", Icons.person_outline),
          _activityTile("Funding requests — owner approves in app",
              "Policy", Icons.account_balance_wallet_outlined),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _activityTile(
      String title, String time, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.withOpacity(0.2),
            child: Icon(icon),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                Text(time,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
