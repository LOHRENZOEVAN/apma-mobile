// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web; // Ensure you are using the web config if targeting the web
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '##########################',
    appId: '########',
    messagingSenderId: '##############################################',
    projectId: 'apma-flutter',
  );
}
