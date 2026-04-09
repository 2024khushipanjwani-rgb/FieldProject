import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'worker_details_screen.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

  String get _todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _updateWorkerAttendance(
    BuildContext context, {
    required String workerId,
    required String workerName,
    required String status,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(workerId);
    final attendanceRef = userRef.collection('attendance').doc(_todayKey);
    final now = DateTime.now();
    final formattedTime =
        "${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    try {
      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final attendanceSnapshot = await transaction.get(attendanceRef);

        final userData = userSnapshot.data() ?? <String, dynamic>{};
        int daysWorked = (userData['daysWorked'] as num?)?.toInt() ?? 0;
        int daysAbsent = (userData['daysAbsent'] as num?)?.toInt() ?? 0;
        final totalHolidays = (userData['totalHolidays'] as num?)?.toInt() ?? 0;
        final totalWorkingDays =
            (userData['totalWorkingDays'] as num?)?.toInt() ?? 26;
        final savedHourlyWage = (userData['hourlyWage'] as num?)?.toDouble();
        final legacyDailyWage = (userData['dailyWage'] as num?)?.toDouble();
        final hourlyWage = savedHourlyWage ??
            (legacyDailyWage != null ? legacyDailyWage / 8 : 80.0);
        final defaultDailyHours =
            (userData['defaultDailyHours'] as num?)?.toInt() ?? 8;
        final deductions = (userData['deductions'] as num?)?.toDouble() ?? 0.0;

        final previousStatus =
            (attendanceSnapshot.data()?['status'] as String?)?.toLowerCase();
        final nextStatus = status.toLowerCase();
        final markedAt = attendanceSnapshot.data()?['markedAt'];

        void decrementCountFor(String? currentStatus) {
          if (currentStatus == 'present' || currentStatus == 'late') {
            daysWorked = daysWorked > 0 ? daysWorked - 1 : 0;
          } else if (currentStatus == 'absent') {
            daysAbsent = daysAbsent > 0 ? daysAbsent - 1 : 0;
          }
        }

        void incrementCountFor(String currentStatus) {
          if (currentStatus == 'present' || currentStatus == 'late') {
            daysWorked += 1;
          } else if (currentStatus == 'absent') {
            daysAbsent += 1;
          }
        }

        if (previousStatus != nextStatus) {
          decrementCountFor(previousStatus);
          incrementCountFor(nextStatus);
        }

        transaction.set(attendanceRef, {
          'status': status,
          'checkInDisplay': nextStatus == 'absent' ? '-' : formattedTime,
          'approvalStatus': 'approved',
          'approvedByAdmin': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'markedAt': markedAt ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'daysWorked': daysWorked,
          'daysAbsent': daysAbsent,
          'totalHolidays': totalHolidays,
          'totalWorkingDays': totalWorkingDays,
          'hourlyWage': hourlyWage,
          'defaultDailyHours': defaultDailyHours,
          'deductions': deductions,
          'lastCheckIn': nextStatus == 'absent' ? '-' : formattedTime,
          'todayStatus': status,
          'todayApprovalStatus': 'approved',
          'todayCheckInDisplay': nextStatus == 'absent' ? '-' : formattedTime,
          'todayApprovedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await firestore.collection('admin_notifications').add({
        'type': 'attendance_updated_by_admin',
        'title': 'Attendance updated',
        'message': '$workerName approved as $status for today.',
        'workerId': workerId,
        'workerName': workerName,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore
          .collection('users')
          .doc(workerId)
          .collection('notifications')
          .add({
        'type': 'attendance_approved',
        'title': 'Attendance approved',
        'message': 'Admin approved your attendance as $status.',
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $workerName as $status')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update attendance.')),
      );
    }
  }

  Widget _statusButton(
    BuildContext context, {
    required String workerId,
    required String workerName,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _updateWorkerAttendance(
          context,
          workerId: workerId,
          workerName: workerName,
          status: label,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: workersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load workers.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No workers found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final workerId = docs[index].id;
              final workerName =
                  (data['username'] as String?)?.trim().isNotEmpty == true
                      ? data['username'] as String
                      : (data['email'] as String?) ?? 'Worker';
              final daysWorked = (data['daysWorked'] as num?)?.toInt() ?? 0;
              final daysAbsent = (data['daysAbsent'] as num?)?.toInt() ?? 0;
              final todayStatus =
                  (data['todayStatus'] as String?) ?? 'Not marked';
              final todayApproval =
                  (data['todayApprovalStatus'] as String?) ?? '-';
              final todayTime =
                  (data['todayCheckInDisplay'] as String?) ?? '--:--';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerDetailsScreen(workerId: workerId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                workerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit worker profile',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WorkerDetailsScreen(workerId: workerId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined, size: 20),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Tap card for full details',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['email']?.toString() ?? '',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Worked: $daysWorked  •  Absent: $daysAbsent',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Today: $todayStatus ($todayApproval) at $todayTime',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _statusButton(
                              context,
                              workerId: workerId,
                              workerName: workerName,
                              label: 'Present',
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _statusButton(
                              context,
                              workerId: workerId,
                              workerName: workerName,
                              label: 'Late',
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            _statusButton(
                              context,
                              workerId: workerId,
                              workerName: workerName,
                              label: 'Absent',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
