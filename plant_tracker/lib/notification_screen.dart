import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'attendance_marked':
      case 'attendance_updated_by_admin':
        return Icons.fact_check_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _timeText(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day ago';
  }

  @override
  Widget build(BuildContext context) {
    final notificationsStream = FirebaseFirestore.instance
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text("Could not load notifications."),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No notifications yet."),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = data['type']?.toString() ?? '';
              final title = data['title']?.toString() ?? 'Notification';
              final message = data['message']?.toString() ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              return ListTile(
                leading: Icon(_iconForType(type)),
                title: Text(title),
                subtitle: Text(
                  message.isEmpty ? _timeText(createdAt) : '$message\n${_timeText(createdAt)}',
                ),
                isThreeLine: message.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}