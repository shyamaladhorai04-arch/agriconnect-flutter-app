import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create or get conversation between two users
  static Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) throw Exception('No user logged in');

      // Create a sorted ID so same conversation always has same ID
      final ids = [currentUid, otherUserId]..sort();
      final conversationId = ids.join('_');

      final docRef = _firestore.collection('conversations').doc(conversationId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'participants': [currentUid, otherUserId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
      }

      return conversationId;
    } catch (e) {
      print('Error getting conversation: $e');
      rethrow;
    }
  }

  /// Send a message
  static Future<void> sendMessage({
    required String conversationId,
    required String message,
    required String senderName,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': uid,
        'senderName': senderName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update last message in conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageFrom': uid,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages stream for a conversation
  static Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    try {
      return _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
      });
    } catch (e) {
      print('Error getting messages: $e');
      rethrow;
    }
  }

  /// Get list of conversations for current user
  static Stream<List<Map<String, dynamic>>> getUserConversations() {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      return _firestore
          .collection('conversations')
          .where('participants', arrayContains: uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data()};
        }).toList();
      });
    } catch (e) {
      print('Error getting conversations: $e');
      rethrow;
    }
  }

  /// Get available contacts based on current user role
  static Stream<List<Map<String, dynamic>>> getAvailableContacts(
      String currentRole) {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final targetCollection = currentRole == 'farmer' ? 'buyers' : 'farmers';

      return _firestore.collection(targetCollection).snapshots().map((snapshot) {
        return snapshot.docs
            .where((doc) => doc.id != uid)
            .map((doc) => {
                  'id': doc.id,
                  'role': currentRole == 'farmer' ? 'buyer' : 'farmer',
                  ...doc.data(),
                })
            .toList();
      });
    } catch (e) {
      print('Error getting available contacts: $e');
      rethrow;
    }
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderId', isNotEqualTo: uid)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      rethrow;
    }
  }

  /// Get unread count for current user
  static Stream<int> getUnreadMessageCount() {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      return _firestore
          .collectionGroup('messages')
          .where('read', isEqualTo: false)
          .where('senderId', isNotEqualTo: uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error getting unread count: $e');
      rethrow;
    }
  }

  /// Delete a conversation
  static Future<void> deleteConversation(String conversationId) async {
    try {
      final messagesRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      final messages = await messagesRef.get();
      for (final msg in messages.docs) {
        await msg.reference.delete();
      }

      await _firestore.collection('conversations').doc(conversationId).delete();
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }
}
