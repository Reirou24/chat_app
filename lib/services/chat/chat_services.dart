import 'dart:io';

import 'package:chat_app/models/message.dart';
import 'package:chat_app/services/media_service.dart';
import 'package:chat_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ChatServices {
  //GET INSTANCE OF FIRESTORE
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  //GET USER STREAM
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
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
    //when the message was sent
    final Timestamp timestamp = Timestamp.now();

    //CREATE NEW MESSAGE
    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
      isRead: false, // Add isRead field
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
        .add(newMessage.toMap());
        
    await _firestore
        .collection("Users")
        .doc(currentUserID)
        .collection("chats")
        .doc(chatRoomID)
        .set({"receiverID": receiverID, "lastMessageTime": timestamp});

    await _firestore
        .collection("Users")
        .doc(receiverID)
        .collection("chats")
        .doc(chatRoomID)
        .set({"receiverID": currentUserID, "lastMessageTime": timestamp});

    // Send notification
    // Get sender name
    DocumentSnapshot senderDoc =
        await _firestore.collection("Users").doc(currentUserID).get();
    String senderName = "";
    if (senderDoc.exists) {
      Map<String, dynamic> senderData =
          senderDoc.data() as Map<String, dynamic>;
      senderName = senderData["username"] ?? senderData["email"];
    } else {
      senderName = currentUserEmail;
    }

    // Send push notification
    await _notificationService.sendMessageNotification(
      senderName: senderName,
      message: message,
      receiverID: receiverID,
      chatRoomID: chatRoomID,
    );
  }

  // GET MESSAGES
  Stream<QuerySnapshot> getMessages(String userId, otherUserID) {
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

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserID) async {
    final String currentUserID = _auth.currentUser!.uid;

    List<String> ids = [currentUserID, otherUserID];
    ids.sort();

    String chatRoomID = ids.join("_");

    // Get unread messages sent by the other user
    QuerySnapshot unreadMessages =
        await _firestore
            .collection("chat_rooms")
            .doc(chatRoomID)
            .collection("messages")
            .where("senderID", isEqualTo: otherUserID)
            .where("receiverID", isEqualTo: currentUserID)
            .where("isRead", isEqualTo: false)
            .get();

    // Mark all as read in a batch operation
    WriteBatch batch = _firestore.batch();

    for (DocumentSnapshot doc in unreadMessages.docs) {
      batch.update(doc.reference, {"isRead": true});
    }

    await batch.commit();
  }

  // Get unread message count for a specific chat
  Stream<int> getUnreadMessageCountStream(String otherUserID) {
    final String currentUserID = _auth.currentUser!.uid;

    List<String> ids = [currentUserID, otherUserID];
    ids.sort();

    String chatRoomID = ids.join("_");

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .where("senderID", isEqualTo: otherUserID)
        .where("receiverID", isEqualTo: currentUserID)
        .where("isRead", isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Get total unread message count across all chats
  Stream<int> getTotalUnreadMessageCountStream() {
    final String currentUserID = _auth.currentUser!.uid;

    return _firestore
        .collection("Users")
        .doc(currentUserID)
        .collection("chats")
        .snapshots()
        .asyncMap((chatRooms) async {
          int totalUnread = 0;

          for (DocumentSnapshot chatRoom in chatRooms.docs) {
            String chatRoomID = chatRoom.id;
            String otherUserID =
                (chatRoom.data() as Map<String, dynamic>)["receiverID"];

            QuerySnapshot unreadMessages =
                await _firestore
                    .collection("chat_rooms")
                    .doc(chatRoomID)
                    .collection("messages")
                    .where("senderID", isEqualTo: otherUserID)
                    .where("receiverID", isEqualTo: currentUserID)
                    .where("isRead", isEqualTo: false)
                    .get();

            totalUnread += unreadMessages.docs.length;
          }

          return totalUnread;
        });
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
    final existingQuery =
        await _firestore
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

    // Send notification for invitation
    DocumentSnapshot senderDoc =
        await _firestore.collection("Users").doc(senderID).get();
    String senderName = "";
    if (senderDoc.exists) {
      Map<String, dynamic> senderData =
          senderDoc.data() as Map<String, dynamic>;
      senderName = senderData["username"] ?? senderData["email"];
    } else {
      senderName = senderEmail;
    }

    await _notificationService.sendMessageNotification(
      senderName: senderName,
      message: "Sent you a chat invitation",
      receiverID: receiverID,
    );
  }

  // Get pending invitations for a user
  Stream<List<Map<String, dynamic>>> getPendingInvitationsStream(
    String userId,
  ) {
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
    await _firestore.collection("invitations").doc(invitationId).update({
      'status': 'accepted',
    });
  }

  // Decline an invitation
  Future<void> declineInvitation(String invitationId) async {
    await _firestore.collection("invitations").doc(invitationId).delete();
  }

  // Check invitation status between two users
  Stream<String?> checkInvitationStatus(String userId1, String userId2) {
    return _firestore
        .collection("invitations")
        .where(
          Filter.or(
            Filter.and(
              Filter('senderID', isEqualTo: userId1),
              Filter('receiverID', isEqualTo: userId2),
            ),
            Filter.and(
              Filter('senderID', isEqualTo: userId2),
              Filter('receiverID', isEqualTo: userId1),
            ),
          ),
        )
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
        .where(
          Filter.or(
            Filter('senderID', isEqualTo: userId),
            Filter('receiverID', isEqualTo: userId),
          ),
        )
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> contacts = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            String contactId =
                data['senderID'] == userId
                    ? data['receiverID']
                    : data['senderID'];

            // Get user details
            DocumentSnapshot userDoc =
                await _firestore.collection("Users").doc(contactId).get();

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              userData['uid'] = contactId;
              contacts.add(userData);
            }
          }

          return contacts;
        });
  }

  String getChatID(String userID1, String userID2) {
    List<String> ids = [userID1, userID2];
    ids.sort();
    return ids.join("_");
  }

  //send media
  Future<void> sendMediaMessage({
    required String receiverID,
    required File mediaFile,
    required String mediaType,
    String? message,
  }) async {
    try {
      final String currentUserID = FirebaseAuth.instance.currentUser!.uid;
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(mediaFile.path)}';
      final String chatID = getChatID(currentUserID, receiverID);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(chatID)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType:
            mediaType.startsWith('image')
                ? 'image/jpeg'
                : (mediaType.startsWith('video')
                    ? 'video/mp4'
                    : 'application/octet-stream'),
      );

      final uploadTask = storageRef.putFile(mediaFile, metadata);
      final snapshot = await uploadTask;
      final String downloadURL = await snapshot.ref.getDownloadURL();

      final messageData = {
        'senderID': currentUserID,
        'senderEmail': _auth.currentUser!.email!,
        'receiverID': receiverID,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'mediaURL': downloadURL,
        'mediaType': mediaType,
        'isRead': false,
      };
      await _firestore
          .collection("chat_rooms")
          .doc(chatID)
          .collection("messages")
          .add(messageData);

      await _firestore
          .collection("Users")
          .doc(currentUserID)
          .collection("chats")
          .doc(chatID)
          .set({
            "receiverID": receiverID, 
            "lastMessageTime": FieldValue.serverTimestamp()
          });

      await _firestore
          .collection("Users")
          .doc(receiverID)
          .collection("chats")
          .doc(chatID)
          .set({
            "receiverID": currentUserID, 
            "lastMessageTime": FieldValue.serverTimestamp()
          });
          
      DocumentSnapshot senderDoc =
          await _firestore.collection("Users").doc(currentUserID).get();
      String senderName = "";
      if (senderDoc.exists) {
        Map<String, dynamic> senderData =
            senderDoc.data() as Map<String, dynamic>;
        senderName = senderData["username"] ?? senderData["email"];
      } else {
        senderName = _auth.currentUser!.email!;
      }
      await _notificationService.sendMessageNotification(
        senderName: senderName,
        message: message ?? "Sent a $mediaType",
        receiverID: receiverID,
        chatRoomID: chatID,
      );
    } catch (e) {
      print("Error in sendMediaMessage: $e");
      rethrow;
    }
  }
}
