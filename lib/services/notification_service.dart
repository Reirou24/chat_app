import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialize notification channels and permissions
  Future<void> initialize() async {
    // Request permission for notifications
    await _requestPermission();
    
    // Configure notification channels
    await _configureLocalNotifications();
    
    // Configure FCM
    await _configureFCM();
    
    // Save the device token to Firestore
    await _saveTokenToFirestore();
  }
  
  // Request permission for notifications
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }
  
  // Configure local notifications
  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
    
    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_messages', // id
        'Chat Messages', // title
        description: 'This channel is used for chat message notifications', // description
        importance: Importance.high,
      );
      
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
  
  // Configure Firebase Cloud Messaging
  Future<void> _configureFCM() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });
    
    // Handle messages when app is opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification');
        // TODO: Handle navigation if needed
      }
    });
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // Save device token to Firestore
  Future<void> _saveTokenToFirestore() async {
    User? user = _auth.currentUser;
    if (user == null) return;
    
    String? token = await _firebaseMessaging.getToken();
    if (token == null) return;
    
    await _firestore
        .collection('Users')
        .doc(user.uid)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }
  
  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    if (notification != null && android != null) {
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'This channel is used for chat message notifications',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(message.data),
      );
    }
  }
  
  // Send push notification for a new message
  Future<void> sendMessageNotification({
    required String senderName,
    required String message,
    required String receiverID,
    String? chatRoomID,
    bool isGroupMessage = false,
    String? groupName,
  }) async {
    try {
      // Get receiver FCM tokens
      DocumentSnapshot userDoc = await _firestore.collection('Users').doc(receiverID).get();
      
      if (!userDoc.exists) return;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List<dynamic> tokens = userData['fcmTokens'] ?? [];
      
      if (tokens.isEmpty) return;
      
      // Build notification payload
      Map<String, dynamic> payload = {
        'notification': {
          'title': isGroupMessage ? groupName : senderName,
          'body': message,
          'sound': 'default',
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': isGroupMessage ? 'group_message' : 'private_message',
          'sender_name': senderName,
          'room_id': chatRoomID,
          'receiver_id': receiverID,
        },
        'registration_ids': tokens,
        'priority': 'high',
      };
      
      // Send to FCM
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY', // Replace with your FCM server key
        },
        body: json.encode(payload),
      );
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
  
  // Update message read status
  Future<void> markMessagesAsRead(String chatRoomID) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .where('receiverID', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
          WriteBatch batch = _firestore.batch();
          
          for (var doc in snapshot.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          
          return batch.commit();
        });
  }
  
  // Get count of unread messages
  Stream<int> getUnreadMessageCountStream(String chatRoomID) {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .where('receiverID', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Get total unread message count across all chats
  Stream<int> getTotalUnreadMessageCountStream() {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return _firestore
        .collection('Users')
        .doc(user.uid)
        .collection('chats')
        .snapshots()
        .asyncMap((snapshot) async {
          int totalCount = 0;
          
          for (var doc in snapshot.docs) {
            String chatRoomID = doc.id;
            
            QuerySnapshot unreadMsgs = await _firestore
                .collection('chat_rooms')
                .doc(chatRoomID)
                .collection('messages')
                .where('receiverID', isEqualTo: user.uid)
                .where('isRead', isEqualTo: false)
                .get();
            
            totalCount += unreadMsgs.docs.length;
          }
          
          return totalCount;
        });
  }
}

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background handlers if needed
  // await Firebase.initializeApp();
  
  debugPrint("Handling a background message: ${message.messageId}");
}