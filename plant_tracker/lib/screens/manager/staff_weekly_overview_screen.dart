import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Manager & owner: per-worker week attendance + estimated gross wages.
class StaffWeeklyOverviewScreen extends StatefulWidget {
  const StaffWeeklyOverviewScreen({super.key});

  @override
  State<StaffWeeklyOverviewScreen> createState() =>
      _StaffWeeklyOverviewScreenState();
}

class _StaffWeeklyOverviewScreenState extends State<StaffWeeklyOverviewScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  static DateTime _mondayOf(DateTime d) {
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static String _dayKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _shiftWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
  }

  static Future<_WeekRollup> _rollup(String workerId, DateTime weekStart) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(workerId)
        .get();
    final u = doc.data();
    if (u == null) return _WeekRollup(gross: 0, presentDays: 0);
    final savedHourly = (u['hourlyWage'] as num?)?.toDouble();
    final legacyDaily = (u['dailyWage'] as num?)?.toDouble();
    final hourly =
        savedHourly ?? (legacyDaily != null ? legacyDaily / 8 : 80.0);
    final dailyHours = (u['defaultDailyHours'] as num?)?.toInt() ?? 8;
    final dailyWage = hourly * dailyHours;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(workerId)
        .collection('attendance');
    double gross = 0;
    var presentDays = 0;
    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final snap = await ref.doc(_dayKey(d)).get();
      final data = snap.data();
      final status = (data?['status'] as String?)?.toLowerCase() ?? '';
      final approval =
          (data?['approvalStatus'] as String?)?.toLowerCase() ?? '';
      final paidLike = status == 'present' || status == 'late';
      final approved =
          approval == 'approved' || data?['approvedByAdmin'] == true;
      if (paidLike && approved) {
        presentDays += 1;
        gross += dailyWage;
      }
    }
    return _WeekRollup(gross: gross, presentDays: presentDays);
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final workersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Team weekly report'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_dayKey(_weekStart)} → ${_dayKey(weekEnd)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: workersStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No workers.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final w = docs[i];
                    final name = (w.data()['username'] as String?) ??
                        (w.data()['email'] as String?) ??
                        'Worker';
                    return FutureBuilder<_WeekRollup>(
                      future: _rollup(w.id, _weekStart),
                      builder: (context, fs) {
                        final r = fs.data;
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(
                              r != null
                                  ? '${r.presentDays}/7 paid days • Gross ₹${r.gross.toStringAsFixed(0)}'
                                  : 'Loading this week…',
                            ),
                            trailing: r == null
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class _WeekRollup {
  _WeekRollup({required this.gross, required this.presentDays});

  final double gross;
  final int presentDays;
}
