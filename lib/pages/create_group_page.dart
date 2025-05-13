import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/services/chat/chat_services.dart';
import 'package:chat_app/services/group_chat_service.dart';
import 'package:flutter/material.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final AuthService _authService = AuthService();
  final ChatServices _chatServices = ChatServices();
  final GroupChatService _groupChatService = GroupChatService();

  //LIST OF MEMBERS
  final List<Map<String, dynamic>> _members = [];
  String _searchQry = '';

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  //create gc with selected members
  void _createGroupChat() async {
    if (_groupNameController.text.trim().isEmpty) {
      _showError("Please enter a group name...");
      return;
    }

    if (_members.isEmpty) {
      _showError("Please select at least one member...");
      return;
    }

    try {
      //get ids from users
      final List<String> memberIds = _members.map((user) => user["uid"] as String).toList();

      final String groupId = await _groupChatService.createGroupChat(
        _groupNameController.text.trim(),
        memberIds,
      );

      Navigator.pop(context, groupId);
    } catch (e) {
      _showError("Failed to create group chat: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Group Chat"),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          //NAME INPUT
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),

          if (_members.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final user = _members[index];
                  final displayName = user["username"] ?? user["email"];

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text(displayName),
                      onDeleted: () {
                        setState(() {
                          _members.removeAt(index);
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for users to add',
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
                    _searchQry = value.toLowerCase();
                  });
                },
              ),
            ),

            //list of users
            Expanded(
              child: StreamBuilder(
                stream: _chatServices.getUserStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error loading users"));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final currentUserId = _authService.getCurrentUser()!.uid;
                  final filteredUsers = snapshot.data!.where((user) {
                    if (user["uid"] == currentUserId) {
                      return false;
                    }

                    bool isAlreadySelected = _members.any((selectedUser) =>
                    selectedUser["uid"] == user["uid"]);
                    if (isAlreadySelected) {
                      return false;
                    }

                    if (_searchQry.isEmpty) {
                      return true;
                    } else {
                      bool emailMatch = user["email"].toString().toLowerCase().contains(_searchQry);
                      bool usernameMatch = false;
                      if (user["username"] != null) {
                        usernameMatch = user["username"].toString().toLowerCase().contains(_searchQry);
                      }

                      return emailMatch || usernameMatch;
                    }
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return const Center(child: Text("No users found"));
                  }

                  return ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final displayName = user["username"] ?? user["email"];
                      final secondaryText = user["username"] != null ? user["email"] : null;

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(displayName[0].toUpperCase()),
                        ),
                        title: Text(displayName),
                        subtitle: secondaryText.isNotEmpty ? Text(secondaryText) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() {
                              _members.add(user);
                            });
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroupChat,
        icon: const Icon(Icons.group_add),
        label: const Text("Create Group Chat"),
      ),
    );
  }
}