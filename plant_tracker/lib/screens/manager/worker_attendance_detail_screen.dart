import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WorkerAttendanceDetailScreen extends StatelessWidget {
  const WorkerAttendanceDetailScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  final String workerId;
  final String workerName;

  static String _dayKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _dayKey(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('$workerName - Attendance'),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(workerId)
            .collection('attendance')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            );
          }
          if (snapshot.hasError) {
            // Include message if possible for debugging
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final rawDocs = snapshot.data?.docs ?? [];
          if (rawDocs.isEmpty) {
            return const Center(
              child: Text('No attendance records found.', style: TextStyle(color: Colors.grey)),
            );
          }

          // Sort descending safely locally bypassing Firebases internal index requirements
          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(rawDocs);
          docs.sort((a, b) => b.id.compareTo(a.id));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final String dateId = docs[index].id;
              
              final isToday = (dateId == todayKey);
              
              final inTime = (data['checkInDisplay'] as String?) ?? '--:--';
              final outTime = (data['checkOutDisplay'] as String?) ?? '--:--';
              final status = (data['status'] as String?)?.toLowerCase() ?? 'unmarked';
              final totalHours = (data['totalHours'] as num?)?.toDouble() ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isToday ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isToday ? Border.all(color: Colors.green.shade300, width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: isToday ? Colors.green.shade700 : Colors.indigo.shade400),
                            const SizedBox(width: 8),
                            Text(
                              dateId,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isToday ? Colors.green.shade900 : Colors.black87,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              )
                            ]
                          ],
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _timeBlock('In Time', inTime, Icons.login, Colors.green),
                        ),
                        Expanded(
                          child: _timeBlock('Out Time', outTime, Icons.logout, Colors.redAccent),
                        ),
                        Expanded(
                          child: _timeBlock(
                            'Total', 
                            '${totalHours.toStringAsFixed(1)} h', 
                            Icons.access_time_filled, 
                            Colors.blueAccent
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _timeBlock(String title, String value, IconData icon, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status) {
      case 'present':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'late':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'absent':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        label = 'UNMARKED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }
}
