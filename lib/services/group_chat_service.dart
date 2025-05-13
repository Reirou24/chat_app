import 'dart:io';

import 'package:chat_app/services/media_service.dart';
import 'package:chat_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupChatService {
  //INSTANCE FIREBASE
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<String> createGroupChat(String groupName, List<String> memberIds) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      final String currentUserName = await _getUserName(currentUserId);
      
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
              
        // Send notification to each member except the creator
        if (memberId != currentUserId) {
          await _notificationService.sendMessageNotification(
            senderName: currentUserName,
            message: "You've been added to a new group: $groupName",
            receiverID: memberId,
            chatRoomID: groupChatDoc.id,
            isGroupMessage: true,
            groupName: groupName
          );
        }
      }

      return groupChatDoc.id;
    } catch (e) {
      throw Exception("Failed to create group chat: $e");
    }
  }

  Future<void> sendGroupMessage(String groupId, String message) async {
    try {
      final String senderId = _auth.currentUser!.uid;
      final String senderName = await _getUserName(senderId);
      
      // Get group details
      DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }
      
      Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
      String groupName = groupData['groupName'];
      List<dynamic> memberIds = groupData['memberIds'];

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
      
      // Send notifications to all members except the sender
      for (String memberId in memberIds) {
        if (memberId != senderId) {
          await _notificationService.sendMessageNotification(
            senderName: senderName,
            message: message,
            receiverID: memberId,
            chatRoomID: groupId,
            isGroupMessage: true,
            groupName: groupName
          );
        }
      }
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

  // Fixed method to properly structure the returned DocumentSnapshot list
  Stream<List<DocumentSnapshot>> getUserGroupChatStream(String userId) {
    return _firestore
        .collection("Users")
        .doc(userId)
        .collection("groups")
        .snapshots()
        .asyncMap((groupsSnapshot) async {
          List<DocumentSnapshot> groupChats = [];

          for (var groupRef in groupsSnapshot.docs) {
            // Get the groupId from the user's groups collection document
            String groupId = groupRef.id;
            
            // Use that ID to get the actual group chat document
            final groupDoc = await _firestore
                .collection("GroupChats")
                .doc(groupId)
                .get();

            if (groupDoc.exists) {
              groupChats.add(groupDoc);
            }
          }

          return groupChats;
        });
  }

  //add member to gc
  Future<void> addMemberToGroup(String groupId, String userId) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      final String currentUserName = await _getUserName(currentUserId);
      
      // Get group name
      DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }
      
      Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
      String groupName = groupData['groupName'];
      
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

      String systemMessage = "A new member was added to the group.";
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "message": systemMessage,
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
          
      // Send notification to the new member
      await _notificationService.sendMessageNotification(
        senderName: currentUserName,
        message: "You've been added to group: $groupName",
        receiverID: userId,
        chatRoomID: groupId,
        isGroupMessage: true,
        groupName: groupName
      );
    } catch (e) {
      throw Exception("Failed to add member to group: $e");
    }
  }

  //remove instead
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      
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

      String systemMessage = "A member was removed from the group.";
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "message": systemMessage,
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
          
      // Get group name for notification
      DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
      if (groupDoc.exists) {
        Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
        String groupName = groupData['groupName'];
        
        // Send notification to the removed member
        await _notificationService.sendMessageNotification(
          senderName: "Group Management",
          message: "You were removed from group: $groupName",
          receiverID: userId,
          chatRoomID: null,
          isGroupMessage: true,
          groupName: groupName
        );
      }
    } catch (e) {
      throw Exception("Failed to remove member from group: $e");
    }
  }

  //change gc name
  Future<void> changeGroupName(String groupId, String newName) async {
    try {
      final String currentUserId = _auth.currentUser!.uid;
      final String currentUserName = await _getUserName(currentUserId);
      
      // Get current group data for member list
      DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }
      
      Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
      List<dynamic> memberIds = groupData['memberIds'];
      String oldGroupName = groupData['groupName'];
      
      // Update group name
      await _firestore.collection("GroupChats").doc(groupId).update({
        "groupName": newName,
      });

      String systemMessage = "The group name has been changed to $newName.";
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": currentUserId,
            "message": systemMessage,
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
          
      // Send notification to all members except the one who changed the name
      for (String memberId in memberIds) {
        if (memberId != currentUserId) {
          await _notificationService.sendMessageNotification(
            senderName: currentUserName,
            message: "Group name changed from '$oldGroupName' to '$newName'",
            receiverID: memberId,
            chatRoomID: groupId,
            isGroupMessage: true,
            groupName: newName
          );
        }
      }
    } catch (e) {
      throw Exception("Failed to change group name: $e");
    }
  }

  //leave gc
  Future<void> leaveGroup(String groupId) async {
    try {
      final String userId = _auth.currentUser!.uid;
      final String userName = await _getUserName(userId);
      
      // Get group data before leaving
      DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }
      
      Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
      String groupName = groupData['groupName'];
      List<dynamic> memberIds = List<dynamic>.from(groupData['memberIds']);
      memberIds.remove(userId); // Remove the leaving user
      
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
      String systemMessage = "$userName has left the group.";
      await _firestore
          .collection("GroupChats")
          .doc(groupId)
          .collection("messages")
          .add({
            "senderId": userId,
            "message": systemMessage,
            "timestamp": Timestamp.now(),
            "isSystemMessage": true,
          });
          
      // Notify other members that this user left
      for (String memberId in memberIds) {
        await _notificationService.sendMessageNotification(
          senderName: "Group Management",
          message: "$userName has left the group",
          receiverID: memberId,
          chatRoomID: groupId,
          isGroupMessage: true,
          groupName: groupName
        );
      }
    } catch (e) {
      throw Exception("Failed to leave group: $e");
    }
  }
  
  // Get unread messages count for a specific group
  Stream<int> getUnreadGroupMessageCount(String groupId) {
    final String userId = _auth.currentUser!.uid;
    
    // Create or get a reference to the user's read receipts for this group
    DocumentReference readReceiptRef = _firestore
        .collection("Users")
        .doc(userId)
        .collection("groupReadStatus")
        .doc(groupId);
        
    return _firestore
        .collection("GroupChats")
        .doc(groupId)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .asyncMap((messagesSnapshot) async {
          DocumentSnapshot readReceiptDoc = await readReceiptRef.get();
          
          Timestamp? lastRead;
          if (readReceiptDoc.exists) {
            lastRead = (readReceiptDoc.data() as Map<String, dynamic>)['lastRead'] as Timestamp?;
          }
          
          if (lastRead == null) {
            return messagesSnapshot.docs.where((doc) => 
                (doc.data() as Map<String, dynamic>)['senderId'] != userId).length;
          }
          
          return messagesSnapshot.docs.where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return data['senderId'] != userId && 
                   data['timestamp'].compareTo(lastRead!) > 0;
          }).length;
        });
  }
  
  // Mark all messages in a group as read
  Future<void> markGroupMessagesAsRead(String groupId) async {
    final String userId = _auth.currentUser!.uid;
    
    await _firestore
        .collection("Users")
        .doc(userId)
        .collection("groupReadStatus")
        .doc(groupId)
        .set({
          'lastRead': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
  
  // Get total unread messages across all groups
  Stream<int> getTotalUnreadGroupMessageCount() {
    final String userId = _auth.currentUser!.uid;
    
    return _firestore
        .collection("Users")
        .doc(userId)
        .collection("groups")
        .snapshots()
        .asyncMap((groupsSnapshot) async {
          int totalCount = 0;
          
          for (var doc in groupsSnapshot.docs) {
            String groupId = doc.id;
            
            // Get the last read timestamp for this group
            DocumentSnapshot readReceiptDoc = await _firestore
                .collection("Users")
                .doc(userId)
                .collection("groupReadStatus")
                .doc(groupId)
                .get();
                
            Timestamp? lastRead;
            if (readReceiptDoc.exists) {
              lastRead = (readReceiptDoc.data() as Map<String, dynamic>)['lastRead'] as Timestamp?;
            }
            
            // Count messages after last read
            QuerySnapshot messagesSnapshot;
            if (lastRead != null) {
              messagesSnapshot = await _firestore
                  .collection("GroupChats")
                  .doc(groupId)
                  .collection("messages")
                  .where("senderId", isNotEqualTo: userId)
                  .where("timestamp", isGreaterThan: lastRead)
                  .get();
            } else {
              messagesSnapshot = await _firestore
                  .collection("GroupChats")
                  .doc(groupId)
                  .collection("messages")
                  .where("senderId", isNotEqualTo: userId)
                  .get();
            }
            
            totalCount += messagesSnapshot.docs.length;
          }
          
          return totalCount;
        });
  }
  
  // Helper method to get user name from Firestore
  Future<String> _getUserName(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection("Users").doc(userId).get();
    if (userDoc.exists) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['name'] ?? userData['username'] ?? "User";
    }
    return "User";
  }

  Future<void> sendGroupMediaMessage({
  required String groupId, 
  required File mediaFile,
  required String mediaType,
  String? message,
}) async {
  try {
    final String senderId = _auth.currentUser!.uid;
    final String senderName = await _getUserName(senderId);
    
    // Get group details
    DocumentSnapshot groupDoc = await _firestore.collection("GroupChats").doc(groupId).get();
    if (!groupDoc.exists) {
      throw Exception("Group not found");
    }
    
    Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
    String groupName = groupData['groupName'];
    List<dynamic> memberIds = groupData['memberIds'];

    // Upload file to storage
    final MediaService mediaService = MediaService();
    String? mediaURL = await mediaService.uploadFile(
      file: mediaFile,
      folderName: 'group_media/$groupId',
    );
    
    String? thumbnailURL;
    if (mediaType == 'video') {
      File? thumbnailFile = await mediaService.generateVideoThumbnail(mediaFile.path);
      if (thumbnailFile != null) {
        thumbnailURL = await mediaService.uploadFile(
          file: thumbnailFile,
          folderName: 'group_media_thumbnails/$groupId',
        );
      }
    }
    
    if (mediaURL == null) {
      throw Exception('Failed to upload media');
    }

    // Construct a descriptive status message based on mediaType
    String lastMessage = "";
    switch (mediaType) {
      case 'image':
        lastMessage = "📷 Image";
        break;
      case 'video':
        lastMessage = "🎥 Video";
        break;
      default:
        lastMessage = "📎 File";
    }
    
    if (message != null && message.isNotEmpty) {
      lastMessage += ": $message";
    }

    // add message to group chat collection
    await _firestore
        .collection("GroupChats")
        .doc(groupId)
        .collection("messages")
        .add({
          "senderId": senderId,
          "message": message,
          "timestamp": Timestamp.now(),
          "isSystemMessage": false,
          "mediaURL": mediaURL,
          "mediaType": mediaType,
          "thumbnailURL": thumbnailURL,
        });

    // update last message in group chat doc
    await _firestore.collection("GroupChats").doc(groupId).update({
      "lastMessage": lastMessage,
      "lastMessageTime": Timestamp.now(),
    });
      
    // Send notifications to all members except the sender
    String notificationMessage = "";
    switch (mediaType) {
      case 'image':
        notificationMessage = "📷 Sent an image";
        break;
      case 'video':
        notificationMessage = "🎥 Sent a video";
        break;
      default:
        notificationMessage = "📎 Sent a file";
    }
    
    if (message != null && message.isNotEmpty) {
      notificationMessage += ": $message";
    }
    
    for (String memberId in memberIds) {
      if (memberId != senderId) {
        await _notificationService.sendMessageNotification(
          senderName: senderName,
          message: notificationMessage,
          receiverID: memberId,
          chatRoomID: groupId,
          isGroupMessage: true,
          groupName: groupName
        );
      }
    }
  } catch (e) {
    print('Error sending group media message: $e');
    throw Exception("Failed to send media message: $e");
  }
}
}