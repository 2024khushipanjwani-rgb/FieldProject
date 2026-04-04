import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';

void main() async {
  // This line is mandatory to prevent the black screen
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase before the app starts
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase failed to load: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plant Tracker',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}