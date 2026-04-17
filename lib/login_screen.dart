import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      debugPrint("Login Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 80, color: Color(0xFF2563EB)),
                      const SizedBox(height: 15),
                      const Text(
                        "PDF Scanner Pro",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Professional Document Scanning",
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () => signInWithGoogle(context),
                        icon: const Icon(Icons.login),
                        label: const Text("Continue with Google"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(double.infinity, 55),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: Colors.blueAccent,
                        ),
                        child: const Text(
                          "Continue as Guest",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
