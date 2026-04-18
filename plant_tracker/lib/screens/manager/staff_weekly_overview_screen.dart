import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:plant_tracker/screens/manager/worker_attendance_detail_screen.dart';

/// Manager & owner: Dynamic Team Dashboard.
class StaffWeeklyOverviewScreen extends StatefulWidget {
  const StaffWeeklyOverviewScreen({super.key});

  @override
  State<StaffWeeklyOverviewScreen> createState() => _StaffWeeklyOverviewScreenState();
}

class _StaffWeeklyOverviewScreenState extends State<StaffWeeklyOverviewScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<_DashboardSummary> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _startDate = _mondayOf(DateTime.now());
    _endDate = _startDate.add(const Duration(days: 6));
    _dashboardFuture = _fetchDashboardData();
  }

  static DateTime _mondayOf(DateTime d) {
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - DateTime.monday));
  }

  static String _dayKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.light(
               primary: Color(0xFF1B5E20),
             ),
           ),
           child: child!,
         );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dashboardFuture = _fetchDashboardData();
      });
    }
  }

  Future<_DashboardSummary> _fetchDashboardData() async {
    final workersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .get();

    final List<_WorkerReport> reports = [];
    double totalGross = 0;
    double totalHours = 0;
    int totalP = 0;
    int totalL = 0;
    int totalA = 0;

    for (var wDoc in workersSnap.docs) {
      final wId = wDoc.id;
      final u = wDoc.data();
      final name = (u['username'] as String?) ?? (u['email'] as String?) ?? 'Worker';

      final savedHourly = (u['hourlyWage'] as num?)?.toDouble();
      final legacyDaily = (u['dailyWage'] as num?)?.toDouble();
      final hourly = savedHourly ?? (legacyDaily != null ? legacyDaily / 8 : 80.0);
      final dailyHours = (u['defaultDailyHours'] as num?)?.toInt() ?? 8;
      final dailyWage = hourly * dailyHours;

      final attSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(wId)
          .collection('attendance')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: _dayKey(_startDate))
          .where(FieldPath.documentId, isLessThanOrEqualTo: _dayKey(_endDate))
          .get();

      double wGross = 0;
      double wHours = 0;
      int wP = 0;
      int wL = 0;
      int wA = 0;

      for (var aDoc in attSnap.docs) {
        final data = aDoc.data();
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        
        if (status == 'present') { wP++; totalP++; }
        else if (status == 'late') { wL++; totalL++; }
        else if (status == 'absent') { wA++; totalA++; }

        if (status == 'present' || status == 'late') {
          final docHours = (data['totalHours'] as num?)?.toDouble() ?? 0;
          wHours += docHours;
          totalHours += docHours;
          
          if (docHours > 0) {
            final earn = hourly * docHours;
            wGross += earn;
            totalGross += earn;
          } else {
            wGross += dailyWage;
            totalGross += dailyWage;
          }
        }
      }
      reports.add(_WorkerReport(
        id: wId,
        name: name,
        gross: wGross,
        totalHours: wHours,
        presentDays: wP,
        lateDays: wL,
        absentDays: wA,
        hasData: attSnap.docs.isNotEmpty,
      ));
    }

    // Sort by total hours descending to keep list ordered
    reports.sort((a, b) => b.totalHours.compareTo(a.totalHours));

    return _DashboardSummary(
      workers: reports,
      totalGross: totalGross,
      totalHours: totalHours,
      totalPresent: totalP,
      totalLate: totalL,
      totalAbsent: totalA,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Match Admin Dashboard background
      appBar: AppBar(
        title: const Text('Team Dashboard'),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: FutureBuilder<_DashboardSummary>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load dashboard data.'));
                }
                final summary = snapshot.data;
                if (summary == null || summary.workers.isEmpty) {
                  return const Center(child: Text('No workers found.'));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    _buildTopInsights(summary),
                    const SizedBox(height: 24),
                    _buildAttendancePieChart(summary),
                    const SizedBox(height: 24),
                    const Text('Worker Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    ...summary.workers.map((w) => _buildWorkerCard(w)),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: const Color(0xFF1B5E20),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: InkWell(
        onTap: _pickDateRange,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.date_range, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '${_dayKey(_startDate)}  →  ${_dayKey(_endDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopInsights(_DashboardSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _insightCard(
            title: 'Total Hours',
            value: '${summary.totalHours.toStringAsFixed(0)}h',
            icon: Icons.access_time_filled,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _insightCard(
            title: 'Est. Payout',
            value: '₹${summary.totalGross.toStringAsFixed(0)}',
            icon: Icons.payments,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _insightCard({required String title, required String value, required IconData icon, required Color color, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(subtitle ?? title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildAttendancePieChart(_DashboardSummary summary) {
    final total = summary.totalPresent + summary.totalLate + summary.totalAbsent;
    if (total == 0) return const SizedBox(); // Hide if no data

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Attendance Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: [
                        if (summary.totalPresent > 0)
                          PieChartSectionData(
                            color: Colors.green.shade400,
                            value: summary.totalPresent.toDouble(),
                            title: '${summary.totalPresent}',
                            radius: 35,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (summary.totalLate > 0)
                          PieChartSectionData(
                            color: Colors.amber.shade500,
                            value: summary.totalLate.toDouble(),
                            title: '${summary.totalLate}',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (summary.totalAbsent > 0)
                          PieChartSectionData(
                            color: Colors.red.shade400,
                            value: summary.totalAbsent.toDouble(),
                            title: '${summary.totalAbsent}',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(Colors.green.shade400, 'Present'),
                    const SizedBox(height: 8),
                    _legendItem(Colors.amber.shade500, 'Late'),
                    const SizedBox(height: 8),
                    _legendItem(Colors.red.shade400, 'Absent'),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _buildWorkerCard(_WorkerReport w) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkerAttendanceDetailScreen(
              workerId: w.id,
              workerName: w.name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              radius: 24,
              child: Text(
                w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade400, fontSize: 18),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                if (!w.hasData)
                  const Text('No data in range', style: TextStyle(color: Colors.grey, fontSize: 12))
                else ...[
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${w.totalHours.toStringAsFixed(1)} hrs', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _microBadge(Colors.green, '${w.presentDays} P'),
                      if (w.lateDays > 0) ...[const SizedBox(width: 4), _microBadge(Colors.amber, '${w.lateDays} L')],
                      if (w.absentDays > 0) ...[const SizedBox(width: 4), _microBadge(Colors.red, '${w.absentDays} A')],
                    ],
                  )
                ]
              ],
            ),
          ),
          if (w.hasData)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Gross Pay', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 2),
                Text('₹${w.gross.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              ],
            ),
        ],
      ),
      ),
    );
  }

  Widget _microBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _WorkerReport {
  _WorkerReport({
    required this.id,
    required this.name,
    required this.gross,
    required this.totalHours,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.hasData,
  });

  final String id;
  final String name;
  final double gross;
  final double totalHours;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final bool hasData;
}

class _DashboardSummary {
  _DashboardSummary({
    required this.workers,
    required this.totalGross,
    required this.totalHours,
    required this.totalPresent,
    required this.totalLate,
    required this.totalAbsent,
  });

  final List<_WorkerReport> workers;
  final double totalGross;
  final double totalHours;
  final int totalPresent;
  final int totalLate;
  final int totalAbsent;
}
