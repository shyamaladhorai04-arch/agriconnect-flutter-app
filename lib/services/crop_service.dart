import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CropService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a new crop for the current farmer
  static Future<String?> addCrop({
    required String title,
    required String status,
    required String quantity,
    required String price,
    required String location,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final docRef = await _firestore.collection('crops').add({
        'farmerId': uid,
        'title': title,
        'status': status,
        'quantity': quantity,
        'price': price,
        'location': location,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error adding crop: $e');
      rethrow;
    }
  }

  /// Get all crops for the current farmer
  static Stream<List<Map<String, dynamic>>> getFarmerCrops() {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      return _firestore
          .collection('crops')
          .where('farmerId', isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
        final docs = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
        // Sort by createdAt on client side to avoid composite index requirement
        docs.sort((a, b) {
          final aTime =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bTime =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bTime.compareTo(aTime);
        });
        return docs;
      });
    } catch (e) {
      print('Error getting farmer crops: $e');
      rethrow;
    }
  }

  /// Get all available crops (for buyer marketplace)
  static Stream<List<Map<String, dynamic>>> getAllAvailableCrops() {
    try {
      return _firestore
          .collection('crops')
          .where('status', isEqualTo: 'Available')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
      });
    } catch (e) {
      print('Error getting available crops: $e');
      rethrow;
    }
  }

  /// Update a crop
  static Future<void> updateCrop({
    required String cropId,
    required String title,
    required String status,
    required String quantity,
    required String price,
    required String location,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      await _firestore.collection('crops').doc(cropId).update({
        'title': title,
        'status': status,
        'quantity': quantity,
        'price': price,
        'location': location,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating crop: $e');
      rethrow;
    }
  }

  /// Delete a crop
  static Future<void> deleteCrop(String cropId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      await _firestore.collection('crops').doc(cropId).delete();
    } catch (e) {
      print('Error deleting crop: $e');
      rethrow;
    }
  }

  /// Get a single crop by ID
  static Future<Map<String, dynamic>?> getCropById(String cropId) async {
    try {
      final doc = await _firestore.collection('crops').doc(cropId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }
      return null;
    } catch (e) {
      print('Error getting crop: $e');
      rethrow;
    }
  }
}
