import 'package:chat_app/models/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatServices {
  //GET INSTANCE OF FIRESTORE
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //GET USER STREAM
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        // Add the document ID as uid to the user data
        user['uid'] = doc.id;
        return user;
      }).toList();
    });
  }

  // SEND MESSAGE
  Future<void> sendMessage(String receiverID, message) async {
    //GET USER INFO
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    //when the mssage was sent
    final Timestamp timestamp = Timestamp.now();

    //CREATE NEW MESSAGE
    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
    );

    //CREATE CHAT ROOM ID FOR TWO USERS 
    List<String> ids = [currentUserID, receiverID];
    ids.sort(); //SORT TO ENSURE UNIQUENESS

    String chatRoomID = ids.join("_");

    //ADD MESSAGES TO DB
    await _firestore
      .collection("chat_rooms")
      .doc(chatRoomID)
      .collection("messages")
      .add(newMessage.toMap()
    );
  }

  // GET MESSAGE
  Stream<QuerySnapshot> getMessaages(String userId, otherUserID) {
    List<String> ids = [userId, otherUserID];
    ids.sort();

    String chatRoomID = ids.join("_");
    return _firestore
      .collection("chat_rooms")
      .doc(chatRoomID)
      .collection("messages")
      .orderBy("timestamp", descending: false)
      .snapshots();
  }
  
  // NEW METHODS FOR INVITATION FUNCTIONALITY
  
  // Send chat invitation
  Future<void> sendChatInvitation({
    required String senderID,
    required String senderEmail,
    required String receiverID,
    required String receiverEmail,
  }) async {
    // Check if an invitation already exists
    final existingQuery = await _firestore
        .collection("invitations")
        .where('senderID', isEqualTo: senderID)
        .where('receiverID', isEqualTo: receiverID)
        .get();
    
    if (existingQuery.docs.isNotEmpty) {
      // Invitation already exists, don't create a duplicate
      return;
    }
    
    // Create new invitation
    await _firestore.collection("invitations").add({
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'receiverEmail': receiverEmail,
      'status': 'pending',
      'timestamp': Timestamp.now(),
    });
  }
  
  // Get pending invitations for a user
  Stream<List<Map<String, dynamic>>> getPendingInvitationsStream(String userId) {
    return _firestore
        .collection("invitations")
        .where('receiverID', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'senderID': data['senderID'],
              'senderEmail': data['senderEmail'],
              'timestamp': data['timestamp'],
            };
          }).toList();
        });
  }
  
  // Accept an invitation
  Future<void> acceptInvitation(String invitationId) async {
    await _firestore
        .collection("invitations")
        .doc(invitationId)
        .update({'status': 'accepted'});
  }
  
  // Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    await _firestore
        .collection("invitations")
        .doc(invitationId)
        .delete();
  }
  
  // Check invitation status between two users
  Stream<String?> checkInvitationStatus(String userId1, String userId2) {
    return _firestore
        .collection("invitations")
        .where(Filter.or(
          Filter.and(
            Filter('senderID', isEqualTo: userId1),
            Filter('receiverID', isEqualTo: userId2),
          ),
          Filter.and(
            Filter('senderID', isEqualTo: userId2),
            Filter('receiverID', isEqualTo: userId1),
          ),
        ))
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          
          final data = snapshot.docs.first.data();
          final status = data['status'];
          
          // Determine if this user sent or received the invitation
          if (status == 'pending') {
            if (data['senderID'] == userId1) {
              return 'pending'; // Current user sent the invitation
            } else {
              return 'received'; // Current user received the invitation
            }
          }
          
          return status;
        });
  }
  
  // Get stream of user contacts (users with accepted invitations)
  Stream<List<Map<String, dynamic>>> getUserContactsStream(String userId) {
    return _firestore
        .collection("invitations")
        .where('status', isEqualTo: 'accepted')
        .where(Filter.or(
          Filter('senderID', isEqualTo: userId),
          Filter('receiverID', isEqualTo: userId),
        ))
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> contacts = [];
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            String contactId = data['senderID'] == userId 
                ? data['receiverID'] 
                : data['senderID'];
            
            // Get user details
            DocumentSnapshot userDoc = await _firestore
                .collection("Users")
                .doc(contactId)
                .get();
            
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              userData['uid'] = contactId;
              contacts.add(userData);
            }
          }
          
          return contacts;
        });
  }
}