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
      .orderBy("timestamp", descending: true)
      .snapshots();
  }
}