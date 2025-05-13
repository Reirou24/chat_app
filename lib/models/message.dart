import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String? message;
  final Timestamp timestamp;
  final bool isRead;

  final String? mediaURL;
  final String? mediaType;
  final String? thumbnailURL;

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    this.message,
    required this.timestamp,
    required this.isRead,
    this.mediaURL,
    this.mediaType,
    this.thumbnailURL,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'mediaURL': mediaURL,
      'mediaType': mediaType,
      'thumbnailURL': thumbnailURL,
    };
  }
}