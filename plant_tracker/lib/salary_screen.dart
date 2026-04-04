import 'package:flutter/material.dart';

class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _salaryCard("Rahul Sharma", "W001", "₹18,500", "Paid", Colors.green),
                _salaryCard("Priya Patel", "W002", "₹22,000", "Processing", Colors.orange),
                _salaryCard("Amit Kumar", "W003", "₹15,200", "Paid", Colors.green),
                _salaryCard("Sunita Devi", "W004", "₹19,000", "On Hold", Colors.red),
              ],
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
              Text("March 2026 • 4 Records",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _salaryCard(String name, String id, String amount, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), // Fixed warning
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
                  color: color.withValues(alpha: 0.1), // Fixed warning
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
              Text("Net Salary: $amount",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              const Text("View Payslip",
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              const Icon(Icons.chevron_right, color: Colors.blue, size: 18),
            ],
          )
        ],
      ),
    );
  }
}