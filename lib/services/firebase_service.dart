import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  static FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://agriconnect-1fdd3-default-rtdb.firebaseio.com/',
      );

  /// Get a reference to the Firebase Realtime Database
  static FirebaseDatabase getDatabase() {
    return _database;
  }

  /// Write data to the database
  static Future<void> writeData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).set(data);
    } catch (e) {
      print('Error writing data to $path: $e');
      rethrow;
    }
  }

  /// Push data to a new node under a collection path
  static Future<String?> pushData(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final ref = _database.ref(path).push();
      await ref.set(data);
      return ref.key;
    } catch (e) {
      print('Error pushing data to $path: $e');
      rethrow;
    }
  }

  /// Read data from the database
  static Future<DataSnapshot> readData(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      return snapshot;
    } catch (e) {
      print('Error reading data from $path: $e');
      rethrow;
    }
  }

  /// Listen to real-time updates
  static Stream<DatabaseEvent> listenToData(String path) {
    return _database.ref(path).onValue;
  }

  /// Update data in the database
  static Future<void> updateData(String path, Map<String, dynamic> data) async {
    try {
      await _database.ref(path).update(data);
    } catch (e) {
      print('Error updating data at $path: $e');
      rethrow;
    }
  }

  /// Delete data from the database
  static Future<void> deleteData(String path) async {
    try {
      await _database.ref(path).remove();
    } catch (e) {
      print('Error deleting data at $path: $e');
      rethrow;
    }
  }

  /// Get a reference to a specific path
  static DatabaseReference getReference(String path) {
    return _database.ref(path);
  }
}
