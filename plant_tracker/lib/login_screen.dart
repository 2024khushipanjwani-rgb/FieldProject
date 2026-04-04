import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard.dart';
import 'worker_dashboard.dart';

class LoginScreen extends StatefulWidget {
const LoginScreen({super.key});

@override
State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
bool isAdmin = true;
bool isLoading = false;

final TextEditingController _phoneController = TextEditingController();
final TextEditingController _otpController = TextEditingController();

String verificationId = "";
bool otpSent = false;

// SEND OTP
Future<void> sendOTP() async {
setState(() => isLoading = true);

await FirebaseAuth.instance.verifyPhoneNumber(
  phoneNumber: _phoneController.text.trim(),
  verificationCompleted: (PhoneAuthCredential credential) async {
    await FirebaseAuth.instance.signInWithCredential(credential);
  },
  verificationFailed: (FirebaseAuthException e) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? "Error occurred")),
    );
  },
  codeSent: (String verId, int? resendToken) {
    setState(() {
      verificationId = verId;
      otpSent = true;
      isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("OTP Sent")),
    );
  },
  codeAutoRetrievalTimeout: (String verId) {
    verificationId = verId;
  },
);

}

// VERIFY OTP
Future<void> verifyOTP() async {
setState(() => isLoading = true);

try {
  PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: _otpController.text.trim(),
  );

  await FirebaseAuth.instance.signInWithCredential(credential);

  if (!mounted) return;

  if (isAdmin) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboard()),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WorkerDashboard()),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Invalid OTP")),
  );
}

setState(() => isLoading = false);

}

@override
Widget build(BuildContext context) {
final primaryColor =
isAdmin ? const Color(0xFF1B5E20) : const Color(0xFF3F51B5);

return Scaffold(
  backgroundColor: const Color(0xFFF8FAFC),
  body: SingleChildScrollView(
    child: Column(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius:
                const BorderRadius.only(bottomRight: Radius.circular(80)),
          ),
          child: Center(
            child: Text(
              isAdmin ? "Admin\nManager" : "Worker\nPortal",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number (+91XXXXXXXXXX)",
                  prefixIcon: Icon(Icons.phone),
                ),
              ),

              if (otpSent) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Enter OTP",
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Worker"),
                  Switch(
                    value: isAdmin,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (value) {
                      setState(() {
                        isAdmin = value;
                      });
                    },
                  ),
                  const Text("Admin"),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isLoading
                      ? null
                      : otpSent
                          ? verifyOTP
                          : sendOTP,
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : Text(
                          otpSent ? "VERIFY OTP" : "SEND OTP",
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

}
}