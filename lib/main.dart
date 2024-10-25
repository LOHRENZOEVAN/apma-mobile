import 'package:apma/my_app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // Ensure this is correctly imported

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Ensures Flutter is initialized

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,  // Loads platform-specific options
    );
    print('Firebase initialized successfully!');
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  runApp(const Apma());  // Replace with your root widget
}
