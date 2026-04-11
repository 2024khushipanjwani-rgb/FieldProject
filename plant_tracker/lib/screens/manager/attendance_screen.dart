import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _db = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> workers = [];
  // workerId -> today's attendance record id
  Map<String, String> todayAttendanceIds = {};
  // workerId -> attendance data
  Map<String, Map<String, dynamic>> todayAttendance = {};
  bool isLoading = true;
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? managerId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Find manager id
    final mSnap = await _db.child('managers').get();
    if (mSnap.exists) {
      final managers = Map<String, dynamic>.from(mSnap.value as Map);
      for (final entry in managers.entries) {
        final m = Map<String, dynamic>.from(entry.value as Map);
        if (m['uid'] == uid) managerId = entry.key;
      }
    }
    // Load workers
    final wSnap = await _db.child('workers').get();
    if (wSnap.exists) {
      final raw = Map<String, dynamic>.from(wSnap.value as Map);
      workers = raw.entries.map((e) {
        final w = Map<String, dynamic>.from(e.value as Map);
        w['id'] = e.key;
        return w;
      }).toList();
    }
    // Load today's attendance
    final aSnap = await _db.child('attendance').get();
    if (aSnap.exists) {
      final all = Map<String, dynamic>.from(aSnap.value as Map);
      all.forEach((key, val) {
        final record = Map<String, dynamic>.from(val as Map);
        if (record['date'] == today) {
          todayAttendanceIds[record['workerId']] = key;
          todayAttendance[record['workerId']] = record;
        }
      });
    }
    setState(() => isLoading = false);
  }

  Future<void> _markIn(String workerId, String workerName) async {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final id = 'A${now.millisecondsSinceEpoch}';
    final data = {
      'workerId': workerId,
      'markedBy': managerId ?? 'M001',
      'date': today,
      'status': 'Present',
      'checkIn': timeStr,
      'checkOut': null,
      'hoursWorked': null,
      'lateMinutes': _calcLateMinutes(timeStr),
      'overtimeHours': 0,
      'shift': 'General',
      'deduction': 0,
    };
    await _db.child('attendance/$id').set(data);
    // Notify owner
    final nId = 'N${now.millisecondsSinceEpoch}';
    await _db.child('notifications/$nId').set({
      'type': 'CHECK_IN',
      'recipientRole': 'admin',
      'workerId': workerId,
      'message': '$workerName checked in at $timeStr',
      'time': timeStr,
      'date': today,
      'severity': 'low',
      'read': false,
    });
    setState(() {
      todayAttendanceIds[workerId] = id;
      todayAttendance[workerId] = data;
    });
  }

  Future<void> _markOut(String workerId, String workerName) async {
    final aId = todayAttendanceIds[workerId];
    if (aId == null) return;
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final checkIn = todayAttendance[workerId]?['checkIn'] as String? ?? '09:30';
    final hours = _calcHours(checkIn, timeStr);
    await _db.child('attendance/$aId').update({
      'checkOut': timeStr,
      'hoursWorked': hours,
      'overtimeHours': hours > 8.5 ? hours - 8.5 : 0,
    });
    final nId = 'N${now.millisecondsSinceEpoch}';
    await _db.child('notifications/$nId').set({
      'type': 'CHECK_OUT',
      'recipientRole': 'admin',
      'workerId': workerId,
      'message': '$workerName checked out at $timeStr',
      'time': timeStr,
      'date': today,
      'severity': 'low',
      'read': false,
    });
    setState(() {
      todayAttendance[workerId]?['checkOut'] = timeStr;
      todayAttendance[workerId]?['hoursWorked'] = hours;
    });
  }

  int _calcLateMinutes(String checkIn) {
    final parts = checkIn.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final shiftH = 9, shiftM = 30;
    final diff = (h * 60 + m) - (shiftH * 60 + shiftM);
    return diff > 0 ? diff : 0;
  }

  double _calcHours(String checkIn, String checkOut) {
    double toMins(String t) {
      final p = t.split(':');
      return double.parse(p[0]) * 60 + double.parse(p[1]);
    }
    return (toMins(checkOut) - toMins(checkIn)) / 60;
  }

  Future<void> _markAbsent(String workerId) async {
    final now = DateTime.now();
    final id = 'A${now.millisecondsSinceEpoch}';
    await _db.child('attendance/$id').set({
      'workerId': workerId,
      'markedBy': managerId ?? 'M001',
      'date': today,
      'status': 'Absent',
      'checkIn': null,
      'checkOut': null,
      'hoursWorked': 0,
      'lateMinutes': 0,
      'overtimeHours': 0,
      'shift': 'General',
      'deduction': 0,
    });
    setState(() {
      todayAttendanceIds[workerId] = id;
      todayAttendance[workerId] = {'status': 'Absent'};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                itemBuilder: (context, i) {
                  final w = workers[i];
                  final wId = w['id'] as String;
                  final att = todayAttendance[wId];
                  final checkedIn = att != null && att['checkIn'] != null;
                  final checkedOut = att != null && att['checkOut'] != null;
                  final isAbsent = att?['status'] == 'Absent';
                  return _workerTile(w, wId, checkedIn, checkedOut, isAbsent, att);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _workerTile(Map w, String wId, bool checkedIn, bool checkedOut,
    bool isAbsent, Map? att) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: Text((w['name'] as String)[0],
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${w['department']} • ₹${w['dailyWage']}/day',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              if (isAbsent)
                _badge('Absent', Colors.red)
              else if (checkedOut)
                _badge('Done', Colors.green)
              else if (checkedIn)
                _badge('IN', Colors.blue)
              else
                _badge('—', Colors.grey),
            ],
          ),
          if (checkedIn) ...[
            const SizedBox(height: 8),
            Text('IN: ${att!['checkIn']}  ${checkedOut ? "OUT: ${att['checkOut']}  Hours: ${(att['hoursWorked'] as num).toStringAsFixed(1)}" : ""}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          const SizedBox(height: 12),
          if (!isAbsent) Row(
            children: [
              if (!checkedIn)
                Expanded(child: _actionBtn('Mark IN', Colors.green, () => _markIn(wId, w['name'] as String))),
              if (checkedIn && !checkedOut) ...[
                const SizedBox(width: 8),
                Expanded(child: _actionBtn('Mark OUT', Colors.orange, () => _markOut(wId, w['name'] as String))),
              ],
              if (!checkedIn) ...[
                const SizedBox(width: 8),
                Expanded(child: _actionBtn('Absent', Colors.red, () => _markAbsent(wId))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: color,
      fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(color: Colors.white,
        fontSize: 12, fontWeight: FontWeight.bold)),
    );

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 55, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)]),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mark Attendance',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(today, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
