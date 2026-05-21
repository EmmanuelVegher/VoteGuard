import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAGpxobQFeZKeOiIUaUWPmGgmqKlE_CsFw',
    appId: '1:239455988709:web:44ef0db4c63846356d1d0c',
    messagingSenderId: '239455988709',
    projectId: 'naijaobserve',
    authDomain: 'naijaobserve.firebaseapp.com',
    storageBucket: 'naijaobserve.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGpxobQFeZKeOiIUaUWPmGgmqKlE_CsFw',
    appId: '1:239455988709:android:44ef0db4c63846356d1d0c', // Guessed android ID suffix
    messagingSenderId: '239455988709',
    projectId: 'naijaobserve',
    storageBucket: 'naijaobserve.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGpxobQFeZKeOiIUaUWPmGgmqKlE_CsFw',
    appId: '1:239455988709:ios:44ef0db4c63846356d1d0c', // Guessed ios ID suffix
    messagingSenderId: '239455988709',
    projectId: 'naijaobserve',
    storageBucket: 'naijaobserve.firebasestorage.app',
    iosBundleId: 'org.caritasnigeria.voteguard',
  );
}
