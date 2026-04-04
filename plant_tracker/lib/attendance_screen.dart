import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Mock data for workers
  final List<Map<String, dynamic>> workers = [
    {"name": "Rahul Sharma", "id": "W001", "time": "9:05 AM", "status": "Present", "color": Colors.green},
    {"name": "Priya Patel", "id": "W002", "time": "9:12 AM", "status": "Present", "color": Colors.green},
    {"name": "Amit Kumar", "id": "W003", "time": "-", "status": "Absent", "color": Colors.red},
    {"name": "Sunita Devi", "id": "W004", "time": "8:35 AM", "status": "Late", "color": Colors.orange},
    {"name": "Rajesh Singh", "id": "W005", "time": "9:02 AM", "status": "Present", "color": Colors.green},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(),
          _buildSummaryCards(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final worker = workers[index];
                return _buildWorkerCard(
                  worker['name'],
                  worker['id'],
                  worker['time'],
                  worker['status'],
                  worker['color'],
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

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          _statBox("Total", "45", Colors.blue),
          const SizedBox(width: 10),
          _statBox("Present", "42", Colors.green),
          const SizedBox(width: 10),
          _statBox("Absent", "03", Colors.red),
        ],
      ),
    );
  }

  Widget _statBox(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(String name, String id, String time, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Text(name[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(id, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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