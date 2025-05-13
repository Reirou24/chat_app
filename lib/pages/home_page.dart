import 'package:chat_app/components/drawer_widget.dart';
import 'package:chat_app/components/user_tile_widget.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/pages/create_group_page.dart';
import 'package:chat_app/pages/group_chat_page.dart';
import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/services/chat/chat_services.dart';
import 'package:chat_app/services/group_chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //CHAT AND AUTH SERVICES
  final ChatServices _chatServices = ChatServices();
  final AuthService _authService = AuthService();
  final GroupChatService _groupChatService = GroupChatService();
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // State to track which users have pending invitations
  final Map<String, bool> _pendingInvitations = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Send chat invitation
  void _sendInvitation(String receiverID, String receiverEmail, String? receiverUsername) {
    _chatServices.sendChatInvitation(
      senderID: _authService.getCurrentUser()!.uid,
      senderEmail: _authService.getCurrentUser()!.email!,
      receiverID: receiverID,
      receiverEmail: receiverEmail,
    ).then((_) {
      setState(() {
        _pendingInvitations[receiverID] = true;
      });
      
      // Display username if available, otherwise use email
      final displayName = receiverUsername?.isNotEmpty == true ? receiverUsername : receiverEmail;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $displayName'))
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $error'))
      );
    });
  }

  void _navigateToCreateGroupPage() async {
    final String? groupId = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupPage(),
      ),
    );

    if (groupId != null) {
      //get group name before navigating
      final groupDoc = await FirebaseFirestore.instance
          .collection("GroupChats")
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final groupName = groupDoc["groupName"];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatPage(
              groupId: groupId, 
              groupName: groupName
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.grey,
        elevation: 0,
        actions: [
          // Notification icon with badge showing pending invitation count
          StreamBuilder(
            stream: _chatServices.getPendingInvitationsStream(_authService.getCurrentUser()!.uid),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData && snapshot.data != null) {
                count = snapshot.data!.length;
              }
              
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      _showInvitationsDialog(context);
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: const DrawerWidget(),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users by email or username...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.grey[200],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Tabs for Contacts and Discover
          DefaultTabController(
            length: 3,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Contacts'),
                      Tab(text: 'Groups'),
                      Tab(text: 'Discover'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorSize: TabBarIndicatorSize.label,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Contacts tab - shows users you're already chatting with
                        _buildContactsList(),

                        // Groups tab - shows groups you're a member of
                        _buildGroupsList(),
                        
                        // Discover tab - shows all users you can invite
                        _buildUserList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroupPage,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.group_add),
        tooltip: 'Create Group Chat',
      ),
    );
  }

  // Show dialog with pending invitations
  void _showInvitationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Invitations'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder(
            stream: _chatServices.getPendingInvitationsStream(_authService.getCurrentUser()!.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("Error loading invitations");
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No pending invitations");
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final invitation = snapshot.data![index];
                  return ListTile(
                    title: Text(invitation['senderEmail']),
                    subtitle: const Text('Wants to chat with you'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () {
                            _chatServices.acceptInvitation(invitation['id']);
                            Navigator.pop(context);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            _chatServices.declineInvitation(invitation['id']);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Build the list of users you're already chatting with
  Widget _buildContactsList() {
    return StreamBuilder(
      stream: _chatServices.getUserContactsStream(_authService.getCurrentUser()!.uid), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading contacts"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No contacts yet"));
        }

        return ListView(
          children: snapshot.data!.map<Widget>((userData) {
            // Get display name - prefer username over email if available
            final String displayName = userData["username"] ?? userData["email"];
            final String contactId = userData["uid"];
            final String currentUserId = _authService.getCurrentUser()!.uid;
                
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(displayName),
              subtitle: StreamBuilder<QuerySnapshot>(
                stream: _getLastMessageStream(currentUserId, contactId),
                builder: (context, msgSnapshot) {
                  if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                    final latestMessage = msgSnapshot.data!.docs.first;
                    final isSentByCurrentUser = latestMessage["senderID"] == currentUserId;
                    final timestamp = latestMessage["timestamp"] as Timestamp;
                    
                    // Format timestamp
                    final dateTime = timestamp.toDate();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
                    
                    String timeString;
                    if (messageDate == today) {
                      // If message is from today, show only time
                      timeString = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
                    } else if (messageDate == today.subtract(const Duration(days: 1))) {
                      // If message is from yesterday
                      timeString = "Yesterday";
                    } else {
                      // Otherwise show date
                      timeString = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
                    }
                    
                    return Row(
                      children: [
                        // Message text
                        Expanded(
                          child: Text(
                            "${isSentByCurrentUser ? 'You: ' : ''} ${latestMessage["message"]}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Timestamp
                        const SizedBox(width: 8),
                        Text(
                          timeString,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    );
                  }
                  return const Text("No messages yet");
                },
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => 
                  ChatPage(
                    receiverUsername: userData["username"] ?? userData["email"],
                    receiverID: userData["uid"],
                  )
                ));
              },
            );
          }).toList(),
        );
      },
    );
  }

  // Helper method to get last message stream between two users
  Stream<QuerySnapshot> _getLastMessageStream(String userId, String otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();

    String chatRoomID = ids.join("_");
    return FirebaseFirestore.instance
      .collection("chat_rooms")
      .doc(chatRoomID)
      .collection("messages")
      .orderBy("timestamp", descending: true)
      .limit(1)
      .snapshots();
  }

  Widget _buildGroupsList() {
    return StreamBuilder(
      stream: _groupChatService.getUserGroupChatStream(_authService.getCurrentUser()!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading groups: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("No groups yet"),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateGroupPage,
                  icon: const Icon(Icons.group_add),
                  label: const Text("Create Group"),
                ),
              ],
            )
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final DocumentSnapshot group = snapshot.data![index];
            final String groupId = group.id;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.group, color: Colors.white),
              ),
              title: Text(group["groupName"]),
              subtitle: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection("GroupChats")
                  .doc(groupId)
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .limit(1)
                  .snapshots(),
                builder: (context, msgSnapshot) {
                  if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                    final latestMessage = msgSnapshot.data!.docs.first;
                    final isSystemMessage = latestMessage["isSystemMessage"] == true;
                    
                    if (isSystemMessage) {
                      return Text(
                        latestMessage["message"],
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    } else {
                      return FutureBuilder(
                        future: FirebaseFirestore.instance
                          .collection("Users")
                          .doc(latestMessage["senderId"])
                          .get(),
                        builder: (context, userSnapshot) {
                          String senderName = "";
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            senderName = userSnapshot.data!["username"] ??
                              userSnapshot.data!["email"]; 

                            if (latestMessage["senderId"] == _authService.getCurrentUser()!.uid) {
                              senderName = "You";
                            }
                          }

                          return Text(
                            "$senderName: ${latestMessage["message"]}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      );
                    }
                  }
                  return const Text("No messages yet");
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupChatPage(
                      groupId: groupId,
                      groupName: group["groupName"],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Build the list of all users for discovery and invitation
  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatServices.getUserStream(), 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter users based on search query
        final filteredUsers = snapshot.data!.where((userData) {
          // Don't show current user
          if (userData["email"] == _authService.getCurrentUser()!.email) {
            return false;
          }
          
          // Apply search filter
          if (_searchQuery.isEmpty) {
            return true;
          } else {
            // Check if email matches search query
            bool emailMatch = userData["email"].toString().toLowerCase().contains(_searchQuery);
            
            // Check if username matches search query (if username exists)
            bool usernameMatch = false;
            if (userData["username"] != null) {
              usernameMatch = userData["username"].toString().toLowerCase().contains(_searchQuery);
            }
            
            // Return true if either email or username matches
            return emailMatch || usernameMatch;
          }
        }).toList();

        if (filteredUsers.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userData = filteredUsers[index];
            final bool isPending = _pendingInvitations[userData["uid"]] == true;
            
            // Get username if available
            final String? username = userData["username"];
            
            // Get display name - prefer username over email
            final String displayName = username != null ? username : userData["email"];
            
            // Get secondary text (show email if username is primary)
            final String secondaryText = username != null ? userData["email"] : "";
            
            return StreamBuilder(
              stream: _chatServices.checkInvitationStatus(
                _authService.getCurrentUser()!.uid,
                userData["uid"],
              ),
              builder: (context, statusSnapshot) {
                String statusText = "";
                bool canInvite = true;
                
                if (statusSnapshot.hasData && statusSnapshot.data != null) {
                  final status = statusSnapshot.data!;
                  if (status == "accepted") {
                    statusText = "Connected";
                    canInvite = false;
                  } else if (status == "pending") {
                    statusText = "Invitation Sent";
                    canInvite = false;
                  } else if (status == "received") {
                    statusText = "Invitation Received";
                    canInvite = false;
                  }
                }
                
                return ListTile(
                  leading: CircleAvatar(
                    // Use first letter of username if available, otherwise use email
                    child: Text(displayName[0].toUpperCase()),
                  ),
                  title: Text(displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (secondaryText.isNotEmpty) 
                        Text(secondaryText, style: TextStyle(fontSize: 12)),
                      if (statusText.isNotEmpty)
                        Text(statusText),
                    ],
                  ),
                  trailing: canInvite
                    ? TextButton(
                        onPressed: () => _sendInvitation(
                          userData["uid"],
                          userData["email"],
                          username,
                        ),
                        child: const Text("Invite"),
                      )
                    : null,
                  onTap: statusText == "Connected"
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverUsername: userData["username"] ?? userData["email"],
                              receiverID: userData["uid"],
                            ),
                          ),
                        );
                      }
                    : null,
                );
              },
            );
          },
        );
      },
    );
  }
}