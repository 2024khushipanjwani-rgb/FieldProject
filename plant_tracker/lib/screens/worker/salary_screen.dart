import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'on hold':
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
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'worker')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load payroll data.'));
                }

                final workers = snapshot.data?.docs ?? [];
                if (workers.isEmpty) {
                  return const Center(child: Text('No worker payroll records found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final data = workers[index].data();
                    final name = (data['username'] as String?) ??
                        (data['email'] as String?) ??
                        'Worker';
                    final savedHourlyWage =
                        (data['hourlyWage'] as num?)?.toDouble();
                    final legacyDailyWage =
                        (data['dailyWage'] as num?)?.toDouble();
                    final hourlyWage = savedHourlyWage ??
                        (legacyDailyWage != null ? legacyDailyWage / 8 : 80);
                    final daysWorked = (data['daysWorked'] as num?)?.toDouble() ?? 0;
                    final defaultDailyHours =
                        (data['defaultDailyHours'] as num?)?.toDouble() ?? 8;
                    final deductions = (data['deductions'] as num?)?.toDouble() ?? 0;
                    final monthlyHours = daysWorked * defaultDailyHours;
                    final netSalary = (hourlyWage * monthlyHours) - deductions;
                    final status = (data['salaryStatus'] as String?) ?? 'Processing';

                    return _SalaryCard(
                      name: name,
                      id: workers[index].id,
                      amount: "₹${netSalary.toStringAsFixed(0)}",
                      subtitle:
                          "₹${hourlyWage.toStringAsFixed(0)}/hr × ${monthlyHours.toStringAsFixed(0)} hrs",
                      status: status,
                      color: _statusColor(status),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        // Salary usually uses an Orange/Amber theme in your Figma
        gradient: LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFFFB300)]),
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
              Text("Payroll Management",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Live Firestore Payroll Records",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  const _SalaryCard({
    required this.name,
    required this.id,
    required this.amount,
    required this.subtitle,
    required this.status,
    required this.color,
  });

  final String name;
  final String id;
  final String amount;
  final String subtitle;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("ID: $id",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Net Salary: $amount",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
