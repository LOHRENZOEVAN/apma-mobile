// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web; // Ensure you are using the web config if targeting the web
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBPFWYJ23Kep5vOHTOhrCq4vxEYcZzfG2c',
    appId: '417291351512',
    messagingSenderId: '417291351512-8o6b7bcc9ltl0an0qtjqaqunv17qecb2.apps.googleusercontent.com',
    projectId: 'apma-flutter',
  );
}
