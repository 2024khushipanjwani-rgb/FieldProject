import 'package:flutter/material.dart';
import 'attendance_screen.dart';
import 'inventory_screen.dart';
import 'salary_screen.dart';
import 'orders_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFigmaHeader(),
            _buildSectionTitle("MANAGEMENT MODULES"),
            _buildModuleGrid(context),
            _buildSectionTitle("RECENT ACTIVITY"),
            _buildRecentActivityList(),
          ],
        ),
      ),
    );
  }

  // --- HEADER SECTION ---
  Widget _buildFigmaHeader() {
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("SONA PEPCEE", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                  Text("Good Morning, Admin 👋", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Friday, March 6, 2026", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  _headerIcon(Icons.notifications_none),
                  const SizedBox(width: 10),
                  _headerIcon(Icons.logout),
                ],
              )
            ],
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _topStatusChip("3", "Present", Colors.green),
              _topStatusChip("3", "Pending", Colors.orange),
              _topStatusChip("2", "Completed", Colors.blue),
              _topStatusChip("2", "Low Stock", Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _headerIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Fixed warning
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _topStatusChip(String count, String label, Color color) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15), // Fixed warning
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 15),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
    );
  }

  // --- MODULE GRID SECTION ---
  Widget _buildModuleGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _moduleCard(context, "Attendance", "Track & manage", "3 present", Icons.calendar_today, Colors.green, const AttendanceScreen()),
          _moduleCard(context, "Salary", "Calculate payroll", "6 employees", Icons.attach_money, Colors.orange, const SalaryScreen()),
          _moduleCard(context, "Inventory", "Stock management", "2 low stock", Icons.inventory_2_outlined, Colors.red, const InventoryScreen()),
          _moduleCard(context, "Orders", "Track shipments", "3 pending", Icons.assignment_outlined, Colors.purple, const OrdersScreen()),
        ],
      ),
    );
  }

  Widget _moduleCard(BuildContext context, String title, String sub, String tag, IconData icon, Color color, Widget? page) {
    return GestureDetector(
      onTap: () {
        if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => page));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$title Screen not linked yet!")),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)], // Fixed warning
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), // Fixed warning
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), // Fixed warning
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(tag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  // --- RECENT ACTIVITY SECTION ---
  Widget _buildRecentActivityList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _activityTile("Worker Rahul marked attendance at 9:05 AM", "9:05 AM", Icons.person_outline, Colors.green),
          _activityTile("New order ORD-2026-D07 received from Metro...", "Yesterday", Icons.shopping_bag_outlined, Colors.purple),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _activityTile(String title, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1), // Fixed warning
            radius: 18,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}