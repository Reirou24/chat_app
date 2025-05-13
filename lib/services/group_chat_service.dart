import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupChatService {
  //INSTANCE FIREBASE
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<String> createGroupChat(String groupName, List<String> memberIds) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      if (!memberIds.contains(currentUserId)) {
        memberIds.add(currentUserId);
      }

      //create doc on firebase
      final groupChatDoc = await _firestore.collection("GroupChats").add({
        "groupName": groupName,
        "createdBy": currentUserId,
        "createdAt": Timestamp.now(),
        "memberIds": memberIds,
        "lastMessage": "",
        "lastMessageTime": Timestamp.now(),
      });

      //create messages collection
      await groupChatDoc.collection("messages").add({
        "senderId": currentUserId,
        "message": "Group chat created!",
        "timestamp": Timestamp.now(),
        "isSystemMessage": true,
      });

      for (String memberId in memberIds) {
        await _firestore
              .collection("Users")
              .doc(memberId)
              .collection("groups")
              .doc(groupChatDoc.id)
              .set({
                "groupId": groupChatDoc.id,
                "joinedAt": Timestamp.now(),
              });
      }

      return groupChatDoc.id;
    } catch (e) {
      throw Exception("Failed to create group chat: $e");
    }
  }

  Future<void> sendGroupMessage(String groupId, message) async {
    try {
      final String senderId = _auth.currentUser!.uid;

      // add message to gc collection
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": senderId,
            "message": message,
            "timestamp": Timestamp.now(),
            "isSystemMessage": false,
          });

      //update last message to gc doc
      await _firestore.collection("GroupChats").doc(groupId).update({
        "lastMessage": message,
        "lastMessageTime": Timestamp.now(),
      });
    } catch (e) {
      throw Exception("Failed to send message: $e");
    }
  }

  Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection("GroupChats")
        .doc(groupId)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Stream<List<DocumentSnapshot>> getUserGroupChatStream(String userId) {
    return _firestore
        .collection("Users")
        .doc(userId)
        .collection("groups")
        .snapshots()
        .asyncMap((groupsSnapshot) async {
          List<DocumentSnapshot> groupChats = [];

          for (var groupRef in groupsSnapshot.docs) {
            final groupDoc = await _firestore
                .collection("GroupChats")
                .doc(groupRef.id)
                .get();

            if (groupDoc.exists) {
              groupChats.add(groupDoc);
            }
          }

          return groupChats;
        });
  }

  //add member to gc
  Future<void> addMemberToGroup(String groupId, userId) async {
    try {
      //add to list
      await _firestore.collection("GroupChats").doc(groupId).update({
        "memberIds": FieldValue.arrayUnion([userId]),
      });

      await _firestore
          .collection("Users")
          .doc(userId)
          .collection("groups")
          .doc(groupId)
          .set({
            "groupId": groupId,
            "joinedAt": Timestamp.now(),
          });

      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": _auth.currentUser!.uid,
            "message": "You have added a new member to the group chat.",
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
    } catch (e) {
      throw Exception("Failed to add member to group: $e");
    }
  }

  //remove instead
  Future<void> removeMemberFromGroup(String groupId, userId) async {
    try {
      //remove to the list
      await _firestore.collection("GroupChats").doc(groupId).update({
        "memberIds": FieldValue.arrayRemove([userId]),
      });

      //remove its reference
      await _firestore
          .collection("Users")
          .doc(userId)
          .collection("groups")
          .doc(groupId)
          .delete();

      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": _auth.currentUser!.uid,
            "message": "A member was removed from the group.",
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
    } catch (e) {
      throw Exception("Failed to remove member from group: $e");
    }
  }

  //change gc name
  Future<void> changeGroupName(String groupId, newName) async {
    try {
      await _firestore.collection("GroupChats").doc(groupId).update({
        "groupName": newName,
      });

      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": _auth.currentUser!.uid,
            "message": "The group name has been changed to $newName.",
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
    } catch (e) {
      throw Exception("Failed to change group name: $e");
    }
  }

  //leave gc
  Future<void> leaveGroup(String groupId) async {
    try {
      final String userId = _auth.currentUser!.uid;

      //remove from list
      await _firestore.collection("GroupChats").doc(groupId).update({
        "memberIds": FieldValue.arrayRemove([userId]),
      });

      //remove group from user's groups
      await _firestore
          .collection("Users")
          .doc(userId)
          .collection("groups")
          .doc(groupId)
          .delete();
      
      //send system message
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": userId,
            "message": "You have left the group chat.",
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
    } catch (e) {
      throw Exception("Failed to leave group: $e");
    }
  }
}