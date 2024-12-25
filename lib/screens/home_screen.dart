import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> messages = [
    {'sender': 'bot', 'text': 'What makes the internet essential?'}
  ];
  bool isRecording = false;
  bool isProcessing = false;
  stt.SpeechToText speech = stt.SpeechToText();
  String recognizedText = "";

  @override
  void initState() {
    super.initState();
    speechToText();
  }

  // initializing the SpeechToText-------------------------
  Future<void> speechToText() async {
    bool available = await speech.initialize();
    if (!available) {
      print("Speech recognition is not available.");
    }
  }
// for the recording one-----------------------------
  Future<void> startRecording() async {
    bool hasPermission = await speech.hasPermission;
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission is required to record audio.")),
      );
      return;
    }

    setState(() {
      isRecording = true;
      recognizedText = "";
    });

    await speech.listen(onResult: (result) async {
      String text = result.recognizedWords;
      print("Recognized text: $text");
      setState(() {
        recognizedText = text;
      });
    });
  }

  Future<void> stopRecording() async {
    setState(() {
      isRecording = false;
    });

    await speech.stop();
    print("Final recognized text: $recognizedText");

    // sending to the backend------------------------
    if (recognizedText.isNotEmpty) {
      String? botResponse = await sendToBackend(recognizedText);
      if (botResponse != null) {
        addMessage('bot', botResponse);
      } else {
        addMessage('bot', 'Failed to process the text. Please try again.');
      }
    }
  }

  Future<String?> sendToBackend(String text) async {
    const String backendUrl = "https://rampoth.pythonanywhere.com/process_text";
    try {
      var response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        return jsonResponse['response'];
      } else {
        return 'Failed to communicate with the backend. Error: ${response.reasonPhrase}';
      }
    } catch (e) {
      print("Error sending text to backend: $e");
      return null;
    }
  }

  void addMessage(String sender, String text) {
    setState(() {
      messages.add({'sender': sender, 'text': text});
    });
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Intractive Bot"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Text("Recognized Text: $recognizedText"),
          Expanded(
            child: ListView.builder(
              padding:EdgeInsets.all(height*0.01),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var message = messages[index];
                bool isBot = message['sender'] == 'bot';
                return Align(
                  alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin:EdgeInsets.symmetric(vertical: height*0.01),
                    padding:EdgeInsets.all(height*0.013),
                    decoration: BoxDecoration(
                      color: isBot ? const Color.fromARGB(255, 179, 137, 251) : Colors.blue[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message['text']!,
                      style: TextStyle(color:Colors.black,fontSize: height*0.019, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(height*0.012),
            child: GestureDetector(
              onTap: isRecording ? stopRecording : startRecording,
              child: CircleAvatar(
                radius: 35,
                backgroundColor: isRecording ? Colors.red : const Color.fromARGB(255, 91, 57, 139),
                child: Text(
                  isRecording ? "Stop" : "Start",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
