import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>> _workersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .snapshots();
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _workersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load attendance.'));
                }

                final workers = snapshot.data?.docs ?? [];
                int presentCount = 0;
                int absentCount = 0;
                for (final worker in workers) {
                  final status =
                      (worker.data()['todayStatus'] as String?) ?? 'Not Marked';
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
                          final workerData = workers[index].data();
                          final name = (workerData['username'] as String?) ??
                              (workerData['email'] as String?) ??
                              'Worker';
                          final status =
                              (workerData['todayStatus'] as String?) ?? 'Not Marked';
                          final time = (workerData['todayCheckInDisplay'] as String?) ??
                              '--:--';
                          final approval = (workerData['todayApprovalStatus']
                                  as String?) ??
                              '-';

                          return _WorkerCard(
                            name: name,
                            id: workers[index].id,
                            time: time,
                            status: status,
                            approvalStatus: approval,
                            color: _statusColor(status),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Attendance", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Today: March 17, 2026", style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
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
    required this.time,
    required this.status,
    required this.approvalStatus,
    required this.color,
  });

  final String name;
  final String id;
  final String time;
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
                    Text(id,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(time,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
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