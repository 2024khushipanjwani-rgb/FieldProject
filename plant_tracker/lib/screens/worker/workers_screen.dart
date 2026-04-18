import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_tracker/core/app_roles.dart';
import 'package:plant_tracker/screens/worker/worker_details_screen.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({super.key});

  String get _todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _markAttendance(
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
        
        final previousStatus =
            (attendanceSnapshot.data()?['status'] as String?)?.toLowerCase();

        if (previousStatus != status) {
          if (previousStatus == 'absent') {
            daysAbsent = daysAbsent > 0 ? daysAbsent - 1 : 0;
          }
          if (previousStatus == 'present' || previousStatus == 'late') {
            daysWorked = daysWorked > 0 ? daysWorked - 1 : 0;
          }

          if (status == 'absent') {
            daysAbsent += 1;
          } else if (status == 'present' || status == 'late') {
            daysWorked += 1;
          }
        }

        if (status == 'absent') {
          transaction.set(attendanceRef, {
            'status': status,
            'checkInDisplay': '-',
            'checkOutDisplay': '-',
            'approvalStatus': 'approved',
            'approvedByAdmin': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'date': _todayKey,
          }, SetOptions(merge: true));

          transaction.set(userRef, {
            'daysWorked': daysWorked,
            'daysAbsent': daysAbsent,
            'todayStatus': status,
            'todayDateKey': _todayKey,
            'todayApprovalStatus': 'approved',
            'todayCheckInDisplay': '-',
            'todayCheckOutDisplay': '-',
            'todayApprovedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          transaction.set(attendanceRef, {
            'status': status,
            'inTimeMillis': now.millisecondsSinceEpoch,
            'checkInDisplay': formattedTime,
            'checkOutDisplay': '--:--',
            'approvalStatus': 'approved',
            'approvedByAdmin': true,
            'approvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'date': _todayKey,
          }, SetOptions(merge: true));

          transaction.set(userRef, {
            'daysWorked': daysWorked,
            'daysAbsent': daysAbsent,
            'lastCheckIn': formattedTime,
            'todayStatus': status,
            'todayDateKey': _todayKey,
            'todayApprovalStatus': 'approved',
            'todayCheckInDisplay': formattedTime,
            'todayCheckOutDisplay': '--:--',
            'todayInTimeMillis': now.millisecondsSinceEpoch,
            'todayApprovedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked $workerName as $status')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _markOutTime(
    BuildContext context, {
    required String workerId,
    required String workerName,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(workerId);
    final attendanceRef = userRef.collection('attendance').doc(_todayKey);
    final wagesRef = userRef.collection('wages').doc(_todayKey);
    final now = DateTime.now();
    final formattedTime =
        "${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    try {
      await firestore.runTransaction((transaction) async {
        final snap = await transaction.get(attendanceRef);
        final userSnap = await transaction.get(userRef);
        if (!snap.exists) throw StateError('no-attendance');
        
        final d = snap.data() ?? {};
        final userData = userSnap.data() ?? {};
        
        final st = (d['status'] as String?)?.toLowerCase() ?? '';
        if (st != 'present' && st != 'late') throw StateError('not-checked-in');
        
        final out = (d['checkOutDisplay'] as String?)?.trim() ?? '';
        if (out.isNotEmpty && out != '-' && out != '--:--') throw StateError('already-out');

        final inTimeMillis = d['inTimeMillis'] as int? ?? userData['todayInTimeMillis'] as int?;
        double totalHours = 8.0; 
        if (inTimeMillis != null) {
          final inTime = DateTime.fromMillisecondsSinceEpoch(inTimeMillis);
          final diff = now.difference(inTime);
          totalHours = diff.inMinutes / 60.0;
        }

        final savedHourlyWage = (userData['hourlyWage'] as num?)?.toDouble() ?? 80.0;
        final dailyWage = totalHours * savedHourlyWage;

        transaction.set(attendanceRef, {
          'checkOutDisplay': formattedTime,
          'outTimeMillis': now.millisecondsSinceEpoch,
          'totalHours': totalHours,
          'checkOutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'todayCheckOutDisplay': formattedTime,
          'todayTotalHours': totalHours,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        transaction.set(wagesRef, {
          'date': _todayKey,
          'totalHours': totalHours,
          'earned': dailyWage,
          'status': 'credited',
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked out-time for $workerName')),
      );
    } on StateError catch (e) {
      if (!context.mounted) return;
      final msg = switch (e.message) {
        'no-attendance' => 'Mark attendance before marking out.',
        'not-checked-in' => 'End shift only after marking present.',
        'already-out' => 'Out-time already recorded.',
        _ => 'Could not mark out.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteWorker(BuildContext context, String workerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Worker'),
        content: const Text('Are you sure you want to permanently delete this worker account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(workerId).delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker deleted successfully.'))
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete worker: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
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
      body: uid == null
          ? const Center(child: Text('Sign in required.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, roleSnap) {
                final role = roleSnap.data?.data()?['role'] as String?;
                final canMark = isManagerRole(role);
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              final todayDateKey = (data['todayDateKey'] as String?) ?? '';
              final isToday = todayDateKey == _todayKey;

              final todayStatus =
                  isToday ? ((data['todayStatus'] as String?) ?? 'Not marked') : 'Not marked';
              final todayApproval =
                  isToday ? ((data['todayApprovalStatus'] as String?) ?? '-') : '-';
              final todayTime =
                  isToday ? ((data['todayCheckInDisplay'] as String?) ?? '--:--') : '--:--';
              final todayOut =
                  isToday ? ((data['todayCheckOutDisplay'] as String?) ?? '--:--') : '--:--';
              final stLower = todayStatus.toLowerCase();


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
                            if (canMark)
                              IconButton(
                                tooltip: 'Delete worker',
                                color: Colors.redAccent,
                                onPressed: () => _deleteWorker(context, workerId),
                                icon: const Icon(Icons.delete_outline, size: 20),
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
                          'Today: $todayStatus ($todayApproval) • In: $todayTime • Out: $todayOut',
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12),
                        ),
                        if (canMark) ...[
                          const SizedBox(height: 12),
                          if (stLower == 'absent')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Marked Absent Today', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            )
                          else if ((stLower == 'present' || stLower == 'late') && todayOut != '--:--' && todayOut != '-')
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text('Shift Ended at $todayOut', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            )
                          else if (stLower == 'present' || stLower == 'late')
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _markOutTime(context, workerId: workerId, workerName: workerName),
                                icon: const Icon(Icons.stop_circle, size: 20),
                                label: const Text('Mark Out Time', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      side: BorderSide(color: Colors.green.shade200),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _markAttendance(context, workerId: workerId, workerName: workerName, status: 'present'),
                                    child: const Text('Present', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange.shade700,
                                      side: BorderSide(color: Colors.orange.shade200),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _markAttendance(context, workerId: workerId, workerName: workerName, status: 'late'),
                                    child: const Text('Late', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(color: Colors.red.shade200),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _markAttendance(context, workerId: workerId, workerName: workerName, status: 'absent'),
                                    child: const Text('Absent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Only managers can change attendance. Owners have read-only access.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
                  },
                );
              },
            ),
    );
  }
}
