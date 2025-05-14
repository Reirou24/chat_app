import 'dart:io';

import 'package:chat_app/components/chat_bubble.dart';
import 'package:chat_app/components/media_chat_bubble.dart';
import 'package:chat_app/components/textfield_widget.dart';
import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/services/chat/chat_services.dart';
import 'package:chat_app/services/media_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String receiverUsername;
  final String receiverID;
  
  ChatPage({super.key, required this.receiverUsername, required this.receiverID});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();

  final ChatServices _chatServices = ChatServices();
  final AuthService _authService = AuthService();
  final MediaService _mediaService = MediaService(); // Moved _mediaService to the state class

  // For textfield focus
  FocusNode myFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        // CREATE A DELAY THEN SCROLL DOWN
        Future.delayed(
          const Duration(milliseconds: 500), 
          () => scrollDown()
        );
      }
    });

    // WAIT
    Future.delayed(const Duration(milliseconds: 500),
      () => scrollDown(),
    );
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // SCROLL DOWN CONTROLLER
  final ScrollController _scrollController = ScrollController();

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  // Sending message method
  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatServices.sendMessage(
        widget.receiverID,
        _messageController.text,
      );

      // After sending clear
      _messageController.clear();
    }

    scrollDown();
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record a video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose a video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('Attach a file'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final File? image = await _mediaService.pickImage(source: source);
    if (image != null) _showMediaMessageDialog(image, 'image');
  }

  Future<void> _pickVideo(ImageSource source) async {
    final File? video = await _mediaService.pickVideo(source: source); // Fixed: removed underscore
    if (video != null) _showMediaMessageDialog(video, 'video');
  }

  Future<void> _pickFile() async {
    final File? file = await _mediaService.pickFile();
    if (file != null) _showMediaMessageDialog(file, 'file');
  }

  void _showMediaMessageDialog(File file, String type) {
    final TextEditingController captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a caption?'), // Added const
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(hintText: 'Optional message...'), // Added const
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'), // Added const
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMediaMessage(file, type, captionController.text);
            },
            child: const Text('Send'), // Added const
          ),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(File mediaFile, String mediaType, String? message) async {
    try {
      if (!mediaFile.existsSync()) {
        throw Exception("File does not exist");
      }
      
      try {
        FirebaseStorage.instance.bucket;
      } catch (e) {
        throw Exception("Firebase Storage is not properly initialized: $e");
      }
      
      print("Sending $mediaType message with file: ${mediaFile.path}");
      print("File size: ${await mediaFile.length()} bytes");
      
      await _chatServices.sendMediaMessage(
        receiverID: widget.receiverID, 
        mediaFile: mediaFile, 
        mediaType: mediaType,
        message: message?.isNotEmpty == true ? message : null,
      );
      
      scrollDown();
    } catch (e) {
      print("Error in _sendMediaMessage: $e");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error sending $mediaType: $e"),
          duration: const Duration(seconds: 2),
        ),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverUsername),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildUserInput(),
        ],
      )
    );
  }

  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder(
      stream: _chatServices.getMessages(widget.receiverID, senderID), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text("Error");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading...");
        }

        return ListView(
          controller: _scrollController,
          children: snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime timestamp;
    if (data["timestamp"] != null) {
      timestamp = (data["timestamp"] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    // CURRENT USER -> LEFT
    bool isCurrentUser = data["senderID"] == _authService.getCurrentUser()!.uid;

    // RECEIVER -> RIGHT
    var alignment = isCurrentUser ?
      Alignment.centerRight : Alignment.centerLeft;

    final String? mediaURL = data["mediaURL"];
    final String? mediaType = data["mediaType"];

    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (mediaURL != null && mediaType != null)
            MediaChatBubble(
              mediaURL: mediaURL, 
              mediaType: mediaType, 
              thumbnailURL: data["thumbnailURL"],
              message: data["message"],
              isSender: isCurrentUser, 
              timestamp: timestamp
            )
          else
            ChatBubble(
              message: data["message"], 
              isSender: isCurrentUser,
              timestamp: timestamp,
            ),
        ],
      )
    );
  }

  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        children: [
          //TODO: FIX MEDIA
          // IconButton(
          //   onPressed: _showMediaOptions,
          //   icon: const Icon(Icons.attach_file), // Added const
          //   color: Colors.grey,
          // ),

          Expanded(
            child: TextfieldWidget(
              controller: _messageController,
              hintText: "Type a message", 
              hideText: false, 
              focusNode: myFocusNode,
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 25),
            child: IconButton(
              onPressed: sendMessage, 
              icon: const Icon(Icons.send), // Added const
              color: Theme.of(context).colorScheme.primary,
            )
          )
        ],                      
      ),
    );
  }
}