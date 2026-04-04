import 'package:flutter/material.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  // --- STATE VARIABLES ---
  bool isAttendanceMarked = false;
  String checkInTime = "--:--";

  // Dashboard Data
  int daysWorked = 21; // Starting at 21 for demo
  int daysAbsent = 4;
  int totalHolidays = 4;
  int totalWorkingDays = 26;

  // Salary Data
  double dailyWage = 650.0;
  double deductions = 200.0;

  // --- LOGIC ---
  void _markAttendance() {
    if (!isAttendanceMarked) {
      setState(() {
        isAttendanceMarked = true;
        daysWorked += 1;
        // Get current time
        final now = DateTime.now();
        checkInTime = "${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance Marked Successfully!")),
      );
    }
  }

  double _calculateAttendanceRate() {
    return (daysWorked / totalWorkingDays) * 100;
  }

  double _calculateNetSalary() {
    return (daysWorked * dailyWage) - deductions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildAttendanceSummary(),
                  const SizedBox(height: 20),
                  _buildSalaryBreakdown(),
                  const SizedBox(height: 20),
                  _buildMyDetails(),
                  const SizedBox(height: 20),
                  _buildWorkingHours(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.engineering, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Worker Portal", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("Rahul Sharma", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.logout, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 5),
              const Text("Sona Pepcee Factory, Unit 3", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          // --- INTERACTIVE ATTENDANCE CARD ---
          GestureDetector(
            onTap: _markAttendance,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isAttendanceMarked ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isAttendanceMarked ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
                    child: Icon(
                      isAttendanceMarked ? Icons.check_circle : Icons.touch_app,
                      color: isAttendanceMarked ? Colors.greenAccent : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAttendanceMarked ? "Attendance Marked ✓" : "Mark Attendance",
                        style: TextStyle(
                          color: isAttendanceMarked ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        isAttendanceMarked ? "Check-in: $checkInTime" : "Tap to check-in for today",
                        style: TextStyle(color: isAttendanceMarked ? Colors.white70 : Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
              SizedBox(width: 10),
              Text("Monthly Attendance Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statBox("22", "Days Worked", Colors.green),
              _statBox("4", "Days Absent", Colors.red),
              _statBox("4", "Total Holidays", Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          _rowInfo("Total Working Days", "$totalWorkingDays days"),
          _rowInfo("Attendance Rate", "${_calculateAttendanceRate().toStringAsFixed(0)}%", isPercent: true),
        ],
      ),
    );
  }

  Widget _statBox(String val, String label, Color color) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 20),
          const SizedBox(height: 5),
          Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSalaryBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Colors.green, size: 20),
              SizedBox(width: 10),
              Text("Salary Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 15),
          _rowInfo("Hours Worked", "176 hrs", icon: Icons.access_time),
          _rowInfo("Overtime", "--", icon: Icons.trending_up),
          _rowInfo("Bonus", "--", icon: Icons.attach_money),
          _rowInfo("Ductions", "₹${deductions.toInt()}", icon: Icons.cancel, color: Colors.red),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Net Salary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Text("₹${_calculateNetSalary().toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text("Basic: ₹14,300 + Overtime: ₹0 + Bonus: ₹0 - Deductions: ₹200", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildMyDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MY DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 15),
          _rowDetail("Worker ID", "W001"),
          _rowDetail("Phone", "9876543210"),
          _rowDetail("Daily Wage", "₹650"),
          _rowDetail("Department", "Production Unit 3"),
        ],
      ),
    );
  }

  Widget _buildWorkingHours() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFFFF9C4), borderRadius: BorderRadius.circular(20)),
      child: const Row(
        children: [
          Icon(Icons.access_time_filled, color: Colors.orange),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Working Hours", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              Text("Mon - Sat: 8:00 AM - 6:00 PM • Sunday Off", style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          )
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _rowInfo(String label, String val, {IconData? icon, Color? color, bool isPercent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 16, color: Colors.grey),
          if (icon != null) const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const Spacer(),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: isPercent ? Colors.green : (color ?? Colors.black87))),
        ],
      ),
    );
  }

  Widget _rowDetail(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}