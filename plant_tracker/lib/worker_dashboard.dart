import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'login_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- STATE VARIABLES ---
  bool isAttendanceMarked = false;
  String checkInTime = "--:--";
  bool isMarkingAttendance = false;
  String username = "Worker";
  String phone = "-";
  String department = "-";
  String workerId = "-";
  String approvalStatus = "pending";
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _attendanceSubscription;
  bool _approvalPopupShown = false;

  // Dashboard Data
  int daysWorked = 21; // Starting at 21 for demo
  int daysAbsent = 4;
  int totalHolidays = 4;
  int totalWorkingDays = 26;

  // Salary Data
  double hourlyWage = 80.0;
  int defaultDailyHours = 8;
  double deductions = 200.0;

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
    _loadAttendanceData();
    _listenForAttendanceApproval();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
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
          checkInTime = (summary['lastCheckIn'] as String?) ?? checkInTime;
        });
      }

      if (todaySnapshot.exists) {
        setState(() {
          isAttendanceMarked = true;
          final today = todaySnapshot.data();
          checkInTime = (today?['checkInDisplay'] as String?) ?? checkInTime;
          approvalStatus = (today?['approvalStatus'] as String?) ?? approvalStatus;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load attendance data.")),
      );
    }
  }

  void _listenForAttendanceApproval() {
    final user = _auth.currentUser;
    if (user == null) return;

    _attendanceSubscription =
        _todayAttendanceDocRef(user.uid).snapshots().listen((snapshot) {
      final today = snapshot.data();
      if (today == null || !mounted) return;

      final newApprovalStatus =
          (today['approvalStatus'] as String?)?.toLowerCase() ?? 'pending';
      final updatedTime = (today['checkInDisplay'] as String?) ?? checkInTime;

      setState(() {
        isAttendanceMarked = snapshot.exists;
        approvalStatus = newApprovalStatus;
        checkInTime = updatedTime;
      });

      if (newApprovalStatus == 'approved' && !_approvalPopupShown) {
        _approvalPopupShown = true;
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Attendance Approved'),
            content: const Text('Admin approved your attendance.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  // --- LOGIC ---
  Future<void> _markAttendance() async {
    if (isAttendanceMarked || isMarkingAttendance) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login again.")),
      );
      return;
    }

    setState(() => isMarkingAttendance = true);

    final now = DateTime.now();
    final formattedTime =
        "${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _userDocRef(user.uid);
        final todayRef = _todayAttendanceDocRef(user.uid);

        final userSnapshot = await transaction.get(userRef);
        final todaySnapshot = await transaction.get(todayRef);

        if (todaySnapshot.exists) {
          throw StateError('attendance-already-marked');
        }

        final userData = userSnapshot.data() ?? <String, dynamic>{};
        final currentDaysWorked = (userData['daysWorked'] as num?)?.toInt() ?? 0;

        transaction.set(todayRef, {
          'status': 'Pending',
          'approvalStatus': 'pending',
          'checkInDisplay': formattedTime,
          'markedAt': FieldValue.serverTimestamp(),
          'checkInAt': FieldValue.serverTimestamp(),
        });

        transaction.set(userRef, {
          'daysWorked': currentDaysWorked,
          'daysAbsent': daysAbsent,
          'totalHolidays': totalHolidays,
          'totalWorkingDays': totalWorkingDays,
          'hourlyWage': hourlyWage,
          'defaultDailyHours': defaultDailyHours,
          'deductions': deductions,
          'lastCheckIn': '--:--',
          'todayStatus': 'Pending',
          'todayApprovalStatus': 'pending',
          'todayCheckInDisplay': formattedTime,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      setState(() {
        isAttendanceMarked = true;
        checkInTime = formattedTime;
        approvalStatus = 'pending';
      });

      await _firestore.collection('admin_notifications').add({
        'type': 'attendance_marked',
        'title': 'Attendance request',
        'message': '$username requested attendance at $formattedTime',
        'workerId': user.uid,
        'workerName': username,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance submitted for admin approval.")),
      );
    } on StateError catch (_) {
      if (!mounted) return;
      setState(() {
        isAttendanceMarked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance already marked for today.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to mark attendance.")),
      );
    } finally {
      if (mounted) {
        setState(() => isMarkingAttendance = false);
      }
    }
  }

  double _calculateAttendanceRate() {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text("Worker Portal", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
              Text("Sona Pepcee Factory, Unit 3", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 25),
          // --- INTERACTIVE ATTENDANCE CARD ---
          GestureDetector(
            onTap: isMarkingAttendance ? null : _markAttendance,
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
                        isMarkingAttendance
                            ? "Saving attendance..."
                            : isAttendanceMarked
                                ? "Attendance Submitted ✓"
                                : "Mark Attendance",
                        style: TextStyle(
                          color: isAttendanceMarked ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        isAttendanceMarked
                            ? "Time: $checkInTime • Status: ${approvalStatus.toUpperCase()}"
                            : "Tap to check-in for today",
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
              _statBox("$daysWorked", "Days Worked", Colors.green),
              _statBox("$daysAbsent", "Days Absent", Colors.red),
              _statBox("$totalHolidays", "Total Holidays", Colors.blue),
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
          _rowInfo(
            "Hours Worked",
            "${daysWorked * defaultDailyHours} hrs",
            icon: Icons.access_time,
          ),
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
          Text(
            "Hourly: ₹${hourlyWage.toInt()} × ${daysWorked * defaultDailyHours} hrs - Deductions: ₹${deductions.toInt()}",
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
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
          _rowDetail("Worker ID", workerId),
          _rowDetail("Phone", phone),
          _rowDetail("Hourly Wage", "₹${hourlyWage.toInt()}"),
          _rowDetail("Department", department),
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