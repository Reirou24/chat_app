import 'package:chat_app/components/drawer_widget.dart';
import 'package:chat_app/components/user_tile_widget.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:chat_app/services/auth/auth_service.dart';
import 'package:chat_app/services/chat/chat_services.dart';
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
  void _sendInvitation(String receiverID, String receiverEmail) {
    _chatServices.sendChatInvitation(
      senderID: _authService.getCurrentUser()!.uid,
      senderEmail: _authService.getCurrentUser()!.email!,
      receiverID: receiverID,
      receiverEmail: receiverEmail,
    ).then((_) {
      setState(() {
        _pendingInvitations[receiverID] = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $receiverEmail'))
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $error'))
      );
    });
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
                hintText: 'Search users...',
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
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Contacts'),
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
          children: snapshot.data!.map<Widget>((userData) =>
            UserTileWidget(
              text: userData["email"],
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => 
                  ChatPage(
                    receiverEmail: userData["email"],
                    receiverID: userData["uid"],
                  )
                ));
              }
            )
          ).toList(),
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
            return userData["email"].toString().toLowerCase().contains(_searchQuery);
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
                    child: Text(userData["email"].toString()[0].toUpperCase()),
                  ),
                  title: Text(userData["email"].toString()),
                  subtitle: statusText.isNotEmpty ? Text(statusText) : null,
                  trailing: canInvite
                    ? TextButton(
                        onPressed: () => _sendInvitation(
                          userData["uid"],
                          userData["email"],
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
                              receiverEmail: userData["email"],
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