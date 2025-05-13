import 'package:chat_app/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final DateTime timestamp;

  const ChatBubble({super.key, required this.message, required this.isSender, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    String formattedTime = DateFormat('h:mm a').format(timestamp);

    return Container(
      decoration: BoxDecoration(
        color: isSender 
          ? (isDarkMode ? Colors.green.shade900 : Colors.green.shade200)
          : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: isSender
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black)
            ),
          ),
          const SizedBox(height: 5),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 10,
              color: isSender
                ? Colors.white.withValues(alpha: 0.7)
                : (isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7))
            )
          )
        ],
      ),
    );
  }
}