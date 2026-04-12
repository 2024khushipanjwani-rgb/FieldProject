import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Manager: submit a cash / fund request to the owner.
class FundingRequestScreen extends StatefulWidget {
  const FundingRequestScreen({super.key});

  @override
  State<FundingRequestScreen> createState() => _FundingRequestScreenState();
}

class _FundingRequestScreenState extends State<FundingRequestScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short reason.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (profile.data()?['username'] as String?)?.trim();
      final displayName = (name != null && name.isNotEmpty)
          ? name
          : (user.email ?? 'Manager');

      await FirebaseFirestore.instance.collection('funding_requests').add({
        'managerId': user.uid,
        'managerName': displayName,
        'amount': amount,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance.collection('owner_notifications').add({
          'type': 'funding_request',
          'title': 'New Fund Request',
          'message': '$displayName requested ₹$amount for: $reason',
          'createdAt': FieldValue.serverTimestamp(),
          'managerId': user.uid,
          'amount': amount,
        });
      } catch (e) {
        debugPrint('Failed to send owner notification: $e');
      }

      if (!mounted) return;
      _amountController.clear();
      _reasonController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to owner.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final stream = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('funding_requests')
            .where('managerId', isEqualTo: uid)
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Request funds'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send to owner'),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Your recent requests',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (stream == null)
            const Text('Sign in to view requests.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Could not load requests.');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.toList();
                
                // Sort locally descending on createdAt to avoid needing a Firestore composite index!
                docs.sort((a, b) {
                  final tA = (a.data()['createdAt'] as Timestamp?)?.toDate();
                  final tB = (b.data()['createdAt'] as Timestamp?)?.toDate();
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA); // Descending
                });

                if (docs.isEmpty) {
                  return Text(
                    'No requests yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  );
                }
                return Column(
                  children: docs.take(20).map((d) {
                    final data = d.data();
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                    final status =
                        (data['status'] as String?) ?? 'pending';
                    final reason = (data['reason'] as String?) ?? '';
                    Color c;
                    switch (status) {
                      case 'approved':
                        c = Colors.green;
                        break;
                      case 'denied':
                        c = Colors.red;
                        break;
                      default:
                        c = Colors.orange;
                    }
                    return Card(
                      child: ListTile(
                        title: Text('₹${amount.toStringAsFixed(0)}'),
                        subtitle: Text(reason),
                        trailing: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}
