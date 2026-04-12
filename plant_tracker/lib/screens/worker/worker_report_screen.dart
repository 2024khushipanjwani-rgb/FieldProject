import 'package:flutter/material.dart';

class WorkerReportScreen extends StatelessWidget {
  const WorkerReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Report details will appear here.'),
      ),
    );
  }
}
