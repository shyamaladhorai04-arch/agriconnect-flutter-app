import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload ID proof document for farmer verification
  static Future<String?> uploadIdProof(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final fileName = 'id_proof_$uid.jpg';
      final ref = _storage.ref('id_proofs/$uid/$fileName');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading ID proof: $e');
      rethrow;
    }
  }

  /// Upload crop image
  static Future<String?> uploadCropImage(File imageFile, String cropId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final fileName = 'crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref('crop_images/$uid/$cropId/$fileName');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading crop image: $e');
      rethrow;
    }
  }

  /// Upload profile picture
  static Future<String?> uploadProfilePicture(File imageFile) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final fileName = 'profile_picture.jpg';
      final ref = _storage.ref('profile_pictures/$uid/$fileName');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print('Error uploading profile picture: $e');
      rethrow;
    }
  }

  /// Delete a file from storage
  static Future<void> deleteFile(String filePath) async {
    try {
      final ref = _storage.ref(filePath);
      await ref.delete();
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  /// Get download URL for a file
  static Future<String?> getDownloadURL(String filePath) async {
    try {
      final ref = _storage.ref(filePath);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }
}
