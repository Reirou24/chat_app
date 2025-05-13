import 'package:chat_app/services/group_chat_service.dart';
import 'package:chat_app/services/auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final GroupChatService _groupChatService = GroupChatService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // For rename dialog
  final TextEditingController _groupNameController = TextEditingController();
  
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
    _groupNameController.text = widget.groupName;
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }
  
  // Load group members
  Future<void> _loadGroupMembers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the group document
      final groupDoc = await _firestore
          .collection("GroupChats")
          .doc(widget.groupId)
          .get();
      
      if (groupDoc.exists) {
        // Get member IDs
        final List<String> memberIds = List<String>.from(groupDoc["memberIds"]);
        
        // Fetch details for each member
        final membersList = <Map<String, dynamic>>[];
        for (String memberId in memberIds) {
          final userDoc = await _firestore
              .collection("Users")
              .doc(memberId)
              .get();
          
          if (userDoc.exists) {
            membersList.add({
              ...userDoc.data()!,
              "uid": memberId,
            });
          }
        }
        
        setState(() {
          _members = membersList;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Error loading group members: $e");
    }
  }

  // Send message
  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      try {
        await _groupChatService.sendGroupMessage(
          widget.groupId,
          _messageController.text.trim(),
        );
        _messageController.clear();
      } catch (e) {
        print("Error sending message: $e");
      }
    }
  }
  
  // Show the rename dialog
  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Group"),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            labelText: "New group name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (_groupNameController.text.trim().isNotEmpty) {
                try {
                  await _groupChatService.changeGroupName(
                    widget.groupId,
                    _groupNameController.text.trim(),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to rename group: $e")),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
  
  // Show members list and manage members
  void _showMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Group Members"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final displayName = member["username"] ?? member["email"];
              final isCurrentUser = member["uid"] == _authService.getCurrentUser()!.uid;
              
              return ListTile(
                leading: CircleAvatar(
                  child: Text(displayName[0].toUpperCase()),
                ),
                title: Text(displayName),
                subtitle: isCurrentUser ? const Text("You") : null,
                trailing: !isCurrentUser ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () async {
                    try {
                      await _groupChatService.removeMemberFromGroup(
                        widget.groupId,
                        member["uid"],
                      );
                      Navigator.pop(context);
                      _loadGroupMembers();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to remove member: $e")),
                      );
                    }
                  },
                ) : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showAddMembersDialog();
            },
            child: const Text("Add Members"),
          ),
        ],
      ),
    );
  }
  
  // Show dialog to add new members
  void _showAddMembersDialog() {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add Members"),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: "Search users",
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder(
                        stream: FirebaseFirestore.instance.collection("Users").snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          // Filter users
                          final currentMemberIds = _members.map((m) => m["uid"]).toList();
                          final users = snapshot.data!.docs
                              .where((doc) => !currentMemberIds.contains(doc.id))
                              .where((doc) {
                                if (searchQuery.isEmpty) return true;
                                
                                final email = doc["email"].toString().toLowerCase();
                                final username = doc["username"]?.toString().toLowerCase() ?? "";
                                
                                return email.contains(searchQuery) || username.contains(searchQuery);
                              })
                              .toList();
                          
                          if (users.isEmpty) {
                            return const Center(child: Text("No users found"));
                          }
                          
                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final displayName = user["username"] ?? user["email"];
                              
                              return ListTile(
                                title: Text(displayName),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () async {
                                    try {
                                      await _groupChatService.addMemberToGroup(
                                        widget.groupId,
                                        user.id,
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Added $displayName to the group")),
                                      );
                                      _loadGroupMembers();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Failed to add member: $e")),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Leave the group
  void _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group"),
        content: const Text("Are you sure you want to leave this group?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _groupChatService.leaveGroup(widget.groupId);
        Navigator.pop(context); // Go back to home page
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to leave group: $e")),
        );
      }
    }
  }
  
  // Build message bubble
  Widget _buildMessageBubble(DocumentSnapshot message) {
    final isCurrentUser = message["senderId"] == _authService.getCurrentUser()!.uid;
    final isSystemMessage = message["isSystemMessage"] == true;
    
    // Find the sender in members list
    String senderName = "Unknown";
    if (!isSystemMessage) {
      final sender = _members.firstWhere(
        (member) => member["uid"] == message["senderId"],
        orElse: () => {"email": "Unknown", "username": null},
      );
      senderName = sender["username"] ?? sender["email"];
    }
    
    if (isSystemMessage) {
      // System message with different styling
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message["message"],
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    // Regular user message
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Text(
                senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isCurrentUser ? Colors.white70 : Colors.black87,
                ),
              ),
            Text(
              message["message"],
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Stream to listen for group name changes
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection("GroupChats").doc(widget.groupId).snapshots(),
      builder: (context, groupSnapshot) {
        // Get current group name
        String currentGroupName = widget.groupName;
        if (groupSnapshot.hasData && groupSnapshot.data != null) {
          currentGroupName = groupSnapshot.data!["groupName"];
        }
        
        return Scaffold(
          appBar: AppBar(
            title: Text(currentGroupName),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.grey,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _showRenameDialog,
              ),
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: _showMembersDialog,
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text("Leave Group"),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'leave') {
                    _leaveGroup();
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Messages list
              Expanded(
                child: StreamBuilder(
                  stream: _groupChatService.getGroupMessagesStream(widget.groupId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("Error loading messages"));
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No messages yet"));
                    }
                    
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final message = snapshot.data!.docs[index];
                        return _buildMessageBubble(message);
                      },
                    );
                  },
                ),
              ),
              
              // Message input
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}