import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    authDomain: 'agriconnect-1fdd3.firebaseapp.com',
    projectId: 'agriconnect-1fdd3',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
    messagingSenderId: '962864183937',
    appId: '1:962864183937:web:56dbe6f40cad3518b56b80',
    measurementId: 'G-GXH3X32S9T',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    appId: '1:962864183937:android:7b50da8400e4182ab56b80',
    messagingSenderId: '962864183937',
    projectId: 'agriconnect-1fdd3',
    databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    appId: '1:962864183937:ios:56b3bc9b39c9229fb56b80',
    messagingSenderId: '962864183937',
    projectId: 'agriconnect-1fdd3',
    databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    appId: '1:962864183937:ios:56b3bc9b39c9229fb56b80',
    messagingSenderId: '962864183937',
    projectId: 'agriconnect-1fdd3',
    databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    appId: '1:962864183937:windows:YOUR_WINDOWS_APP_ID',
    messagingSenderId: '962864183937',
    projectId: 'agriconnect-1fdd3',
    databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyB_soa1bsTpaSNUCkFrAKIESjhNwsvEGsQ',
    appId: '1:962864183937:linux:YOUR_LINUX_APP_ID',
    messagingSenderId: '962864183937',
    projectId: 'agriconnect-1fdd3',
    databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com',
    storageBucket: 'agriconnect-1fdd3.firebasestorage.app',
  );
}
