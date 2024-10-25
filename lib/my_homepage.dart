import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_page.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Start Google Sign-In process
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the sign-in process
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential using Google Auth details
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase using the Google credential
      await FirebaseAuth.instance.signInWithCredential(credential);

      // On successful login, navigate to the home screen or any other desired page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignUpPage()),
      );
    } catch (e) {
      // Display error message if sign-in fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign in with Google: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // Adds horizontal padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo apma.png', height: 120),
              const SizedBox(height: 40),
              const Text(
                "Monitor your animals for optimal performance",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87, // Subtle color for the text
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Navigate to signup page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFF00C853),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
                  backgroundColor: Colors.white,
                  shadowColor: Colors.grey.withOpacity(0.3),
                  elevation: 5,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _signInWithGoogle(context),
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
                  backgroundColor: const Color.fromARGB(255, 159, 234, 191),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
