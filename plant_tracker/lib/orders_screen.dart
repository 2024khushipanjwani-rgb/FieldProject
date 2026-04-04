import 'package:flutter/material.dart';

// Renamed to match the AdminDashboard call
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

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
                _figmaOrderCard("Jeera", "ORD-2026-001", "320 Units", "Processing", Colors.blue),
                _figmaOrderCard("Mango", "ORD-2026-002", "150 Units", "Pending", Colors.orange),
                _figmaOrderCard("Orange", "ORD-2026-003", "500 Units", "Completed", Colors.green),
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
        gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)]),
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
              Text("Order Tracking",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("3 Active Shipments",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figmaOrderCard(String name, String id, String qty, String status, Color color) {
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(id,
                      style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
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
              const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(qty, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              const Text("View Details",
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              const Icon(Icons.chevron_right, color: Colors.blue, size: 18),
            ],
          )
        ],
      ),
    );
  }
}