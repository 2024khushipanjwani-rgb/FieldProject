import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Owner: approve or deny funding requests from managers.
class OwnerFundingScreen extends StatelessWidget {
  const OwnerFundingScreen({super.key});

  Future<void> _setStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      await ref.update({
        'status': status,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedByUid': uid,
      });

      try {
        final requestSnap = await ref.get();
        final managerName = requestSnap.data()?['managerName'] ?? 'Manager';
        
        await FirebaseFirestore.instance.collection('admin_notifications').add({
          'type': 'funding_update',
          'title': 'Request ${status.toUpperCase()}',
          'message': 'The owner has $status the fund request for $managerName.',
          'createdAt': FieldValue.serverTimestamp(),
          'status': status,
        });
      } catch (e) {
        debugPrint('Failed to notify manager: $e');
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $status.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('funding_requests')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Fund requests'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load requests.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No funding requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final amount = (data['amount'] as num?)?.toDouble() ?? 0;
              final reason = (data['reason'] as String?) ?? '';
              final managerName =
                  (data['managerName'] as String?) ?? 'Manager';
              final status = (data['status'] as String?) ?? 'pending';
              final pending = status == 'pending';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: pending
                                ? Colors.orange
                                : (status == 'approved'
                                    ? Colors.green
                                    : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      managerName,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(reason),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _setStatus(
                                context,
                                doc.reference,
                                'denied',
                              ),
                              child: const Text('Deny'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () => _setStatus(
                                context,
                                doc.reference,
                                'approved',
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
