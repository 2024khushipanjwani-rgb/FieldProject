import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:plant_tracker/screens/auth/login_screen.dart';
import 'worker_report_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String checkInTime = "--:--";
  String checkOutTime = "--:--";
  String todayStatusDisplay = "Not recorded";
  String username = "Worker";
  String phone = "-";
  String department = "-";
  String workerId = "-";

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _attendanceSubscription;

  int daysWorked = 0;
  int daysAbsent = 0;
  int totalHolidays = 0;
  int totalWorkingDays = 26;

  double hourlyWage = 80.0;
  int defaultDailyHours = 8;
  double deductions = 0.0;

  String get _todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  DocumentReference<Map<String, dynamic>> _userDocRef(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _todayAttendanceDocRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .doc(_todayKey);
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _listenTodayAttendance();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  void _applyTodayFromDoc(Map<String, dynamic>? today) {
    if (today == null) {
      checkInTime = "--:--";
      checkOutTime = "--:--";
      todayStatusDisplay = "Not recorded";
      return;
    }
    final status = (today['status'] as String?) ?? '—';
    checkInTime = (today['checkInDisplay'] as String?)?.trim().isNotEmpty == true
        ? today['checkInDisplay'] as String
        : "--:--";
    final out = today['checkOutDisplay'] as String?;
    checkOutTime =
        out != null && out.trim().isNotEmpty && out != '-' ? out : "--:--";
    todayStatusDisplay = status;
  }

  Future<void> _loadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final summarySnapshot = await _userDocRef(user.uid).get();
      final todaySnapshot = await _todayAttendanceDocRef(user.uid).get();

      if (!mounted) return;

      final summary = summarySnapshot.data();
      if (summary != null) {
        setState(() {
          username = (summary['username'] as String?)?.trim().isNotEmpty == true
              ? summary['username'] as String
              : username;
          phone = (summary['phone'] as String?)?.trim().isNotEmpty == true
              ? summary['phone'] as String
              : phone;
          department =
              (summary['department'] as String?)?.trim().isNotEmpty == true
                  ? summary['department'] as String
                  : department;
          workerId = user.uid;
          daysWorked = (summary['daysWorked'] as num?)?.toInt() ?? daysWorked;
          daysAbsent = (summary['daysAbsent'] as num?)?.toInt() ?? daysAbsent;
          totalHolidays =
              (summary['totalHolidays'] as num?)?.toInt() ?? totalHolidays;
          totalWorkingDays =
              (summary['totalWorkingDays'] as num?)?.toInt() ?? totalWorkingDays;
          final savedHourlyWage = (summary['hourlyWage'] as num?)?.toDouble();
          final legacyDailyWage = (summary['dailyWage'] as num?)?.toDouble();
          hourlyWage = savedHourlyWage ??
              (legacyDailyWage != null ? legacyDailyWage / 8 : hourlyWage);
          defaultDailyHours =
              (summary['defaultDailyHours'] as num?)?.toInt() ??
                  defaultDailyHours;
          deductions = (summary['deductions'] as num?)?.toDouble() ?? deductions;
          final summaryIn = summary['todayCheckInDisplay'] as String?;
          if (summaryIn != null && summaryIn.isNotEmpty && summaryIn != '--:--') {
            checkInTime = summaryIn;
          }
          final summaryOut = summary['todayCheckOutDisplay'] as String?;
          if (summaryOut != null &&
              summaryOut.isNotEmpty &&
              summaryOut != '--:--' &&
              summaryOut != '-') {
            checkOutTime = summaryOut;
          }
          final ts = summary['todayStatus'] as String?;
          if (ts != null && ts.isNotEmpty) {
            todayStatusDisplay = ts;
          }
        });
      }

      if (todaySnapshot.exists) {
        setState(() {
          _applyTodayFromDoc(todaySnapshot.data());
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load dashboard data.")),
      );
    }
  }

  void _listenTodayAttendance() {
    final user = _auth.currentUser;
    if (user == null) return;

    _attendanceSubscription =
        _todayAttendanceDocRef(user.uid).snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        if (snapshot.exists) {
          _applyTodayFromDoc(snapshot.data());
        } else {
          _applyTodayFromDoc(null);
        }
      });
    });
  }

  double _calculateAttendanceRate() {
    if (totalWorkingDays <= 0) return 0;
    return (daysWorked / totalWorkingDays) * 100;
  }

  double _calculateNetSalary() {
    final monthlyHoursWorked = daysWorked * defaultDailyHours;
    return (monthlyHoursWorked * hourlyWage) - deductions;
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
                  _buildTodayAttendanceCard(),
                  const SizedBox(height: 16),
                  _buildReportButton(),
                  const SizedBox(height: 20),
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
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.engineering,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text("Worker Portal",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.location_on, color: Colors.white70, size: 16),
              SizedBox(width: 5),
              Text("Sona Pepcee Factory, Unit 3",
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAttendanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.indigo.shade700),
              const SizedBox(width: 10),
              const Text(
                "Today's attendance",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Recorded by your manager",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          _rowInfo("Status", todayStatusDisplay,
              color: Colors.black87, boldValue: true),
          _rowInfo("In", checkInTime),
          _rowInfo("Out", checkOutTime),
        ],
      ),
    );
  }

  Widget _buildReportButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3F51B5),
          side: const BorderSide(color: Color(0xFF3F51B5)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerReportScreen()),
          );
        },
        icon: const Icon(Icons.assessment_outlined),
        label: const Text(
          "Wages & attendance report",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
              SizedBox(width: 10),
              Text("Attendance & leave (period summary)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statBox("$daysWorked", "Days worked", Colors.green),
              _statBox("$daysAbsent", "Absent / leave", Colors.red),
              _statBox("$totalHolidays", "Holidays", Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          _rowInfo("Total working days", "$totalWorkingDays days"),
          _rowInfo("Attendance rate",
              "${_calculateAttendanceRate().toStringAsFixed(0)}%",
              isPercent: true),
        ],
      ),
    );
  }

  Widget _statBox(String val, String label, Color color) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 20),
          const SizedBox(height: 5),
          Text(val,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildLeavesAndHolidays() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available, color: Colors.deepPurple, size: 20),
              SizedBox(width: 10),
              Text(
                'Leaves & holidays',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rowInfo(
            'Days worked (period)',
            '$daysWorked days',
            icon: Icons.work_history_outlined,
          ),
          _rowInfo(
            'Days marked absent',
            '$daysAbsent days',
            icon: Icons.event_busy,
            color: Colors.red,
          ),
          _rowInfo(
            'Holidays / scheduled offs (recorded)',
            '$totalHolidays days',
            icon: Icons.beach_access_outlined,
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          Text(
            'Paid leave requests and balances are managed by your manager.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyReportCard(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        borderRadius: BorderRadius.circular(25),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerReportScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                child: const Icon(Icons.bar_chart, color: Colors.indigo),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly report',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Daily attendance & estimated wages for this week',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments, color: Colors.green, size: 20),
              SizedBox(width: 10),
              Text("Salary overview",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 15),
          _rowInfo(
            "Hours (from days worked)",
            "${daysWorked * defaultDailyHours} hrs",
            icon: Icons.access_time,
          ),
          _rowInfo("Overtime", "—", icon: Icons.trending_up),
          _rowInfo("Bonus", "—", icon: Icons.attach_money),
          _rowInfo("Deductions", "₹${deductions.toInt()}",
              icon: Icons.cancel, color: Colors.red),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Estimated net",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                Text("₹${_calculateNetSalary().toInt()}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "₹${hourlyWage.toStringAsFixed(0)}/hr × ${daysWorked * defaultDailyHours} hrs − ₹${deductions.toInt()} deductions",
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildMyDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MY DETAILS",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 15),
          _rowDetail("Worker ID", workerId),
          _rowDetail("Phone", phone),
          _rowDetail("Hourly rate", "₹${hourlyWage.toStringAsFixed(0)}"),
          _rowDetail("Department", department),
        ],
      ),
    );
  }

  Widget _buildWorkingHours() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(20)),
      child: const Row(
        children: [
          Icon(Icons.access_time_filled, color: Colors.orange),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Working hours",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.orange)),
              Text("Mon - Sat: 8:00 AM - 6:00 PM • Sunday off",
                  style: TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          )
        ],
      ),
    );
  }

  Widget _rowInfo(String label, String val,
      {IconData? icon,
      Color? color,
      bool isPercent = false,
      bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 16, color: Colors.grey),
          if (icon != null) const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const Spacer(),
          Text(
            val,
            style: TextStyle(
              fontWeight: boldValue ? FontWeight.bold : FontWeight.w600,
              color: isPercent
                  ? Colors.green
                  : (color ?? Colors.black87),
              fontSize: boldValue ? 14 : 13,
            ),
          ),
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
          Flexible(
            child: Text(val,
                textAlign: TextAlign.end,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
