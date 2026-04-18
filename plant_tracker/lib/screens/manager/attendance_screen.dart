import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey {
    return "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceForDate() async {
    final workersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .get();

    List<Map<String, dynamic>> results = [];
    
    for (var worker in workersSnap.docs) {
      final workerData = worker.data();
      
      // Fetch directly by ID avoiding collectionGroup indexing requirement
      final attDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(worker.id)
          .collection('attendance')
          .doc(_dateKey)
          .get();

      final att = attDoc.data() ?? {};
      
      results.add({
        'id': worker.id,
        'name': workerData['username'] ?? workerData['email'] ?? 'Worker',
        'status': att['status'] ?? 'Not Marked',
        'timeIn': att['checkInDisplay'] ?? '--:--',
        'timeOut': att['checkOutDisplay'] ?? '--:--',
        'totalHours': (att['totalHours'] as num?)?.toDouble() ?? 0.0,
        'approvalStatus': att['approvalStatus'] ?? '-',
      });
    }

    return results;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAttendanceForDate(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load attendance.'));
                }

                final workers = snapshot.data ?? [];
                int presentCount = 0;
                int absentCount = 0;
                for (final worker in workers) {
                  final status = worker['status'] as String;
                  if (status.toLowerCase() == 'present' ||
                      status.toLowerCase() == 'late') {
                    presentCount += 1;
                  } else if (status.toLowerCase() == 'absent') {
                    absentCount += 1;
                  }
                }

                return Column(
                  children: [
                    _SummaryCards(
                      total: workers.length,
                      present: presentCount,
                      absent: absentCount,
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: workers.length,
                        itemBuilder: (context, index) {
                          final worker = workers[index];
                          return _WorkerCard(
                            name: worker['name'],
                            id: worker['id'],
                            timeIn: worker['timeIn'],
                            timeOut: worker['timeOut'],
                            totalHours: worker['totalHours'],
                            status: worker['status'],
                            approvalStatus: worker['approvalStatus'],
                            color: _statusColor(worker['status']),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final d = _selectedDate;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateLine = 'Date: ${months[d.month - 1]} ${d.day}, ${d.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Attendance",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(dateLine,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
          ),
        ],
      ),
    );
  }

}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.total,
    required this.present,
    required this.absent,
  });

  final int total;
  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          _StatBox(label: "Total", count: total.toString(), color: Colors.blue),
          const SizedBox(width: 10),
          _StatBox(
            label: "Present",
            count: present.toString(),
            color: Colors.green,
          ),
          const SizedBox(width: 10),
          _StatBox(label: "Absent", count: absent.toString(), color: Colors.red),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.name,
    required this.id,
    required this.timeIn,
    required this.timeOut,
    required this.totalHours,
    required this.status,
    required this.approvalStatus,
    required this.color,
  });

  final String name;
  final String id;
  final String timeIn;
  final String timeOut;
  final double totalHours;
  final String status;
  final String approvalStatus;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('In: $timeIn',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.logout, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Out: $timeOut',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (totalHours > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 4),
                      Text('Worked ${totalHours.toStringAsFixed(1)} hours today',
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Approval: ${approvalStatus.toUpperCase()}',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}