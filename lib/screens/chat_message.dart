import 'package:flutter/material.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isBot;
  final bool isTyping;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isBot,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: height * 0.01),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: isBot ? height * 0.01 : 0,
                right: isBot ? 0 : height * 0.01,
                bottom: 4,
              ),
              child: Text(
                isBot ? "Bot" : "You",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: height * 0.014,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(height * 0.013),
              decoration: BoxDecoration(
                color: isBot 
                  ? (isTyping ? Colors.grey[300] : const Color.fromARGB(255, 179, 137, 251))
                  : Colors.blue[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: height * 0.019,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}