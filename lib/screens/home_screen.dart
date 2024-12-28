import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'chat_message.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> messages = [
    {'sender': 'bot', 'text': 'What makes the internet essential?'}
  ];
  bool isListening = false;
  bool isSpeaking = false;
  bool isProcessingResponse = false;
  String currentText = "";
  Timer? speechTimer;
  Timer? botResponseTimer;
  stt.SpeechToText speech = stt.SpeechToText();
  StreamController<String>? currentResponseController;

  @override
  void initState() {
    super.initState();
    initializeSpeech();
  }

  @override
  void dispose() {
    speechTimer?.cancel();
    botResponseTimer?.cancel();
    currentResponseController?.close();
    speech.stop();
    super.dispose();
  }

  Future<void> initializeSpeech() async {
    bool available = await speech.initialize(
      onStatus: (status) async {
        print("status: $status");
        if (status == 'done' || status == 'notListening') {
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted) {
            startContinuousListening();
          }
        }
      },
      onError: (error) async {
        print("Speech error: $error"); 
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          startContinuousListening();
        }
      },
    );
    
    if (available) {
      startContinuousListening();
    } else {
      print("Speech recognition not available");
    }
  }

  void startContinuousListening() async {
    if (!speech.isListening && mounted) {
      try {
        await speech.listen(
          onResult: handleSpeechResult,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          listenFor: const Duration(hours: 1),
        );
        setState(() {
          isListening = true;
        });
      } catch (e) {
        print("Error starting listening: $e");
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          startContinuousListening();
        }
      }
    }
  }

  void handleSpeechResult(result) {
    if (mounted) {
      if (isProcessingResponse && result.recognizedWords.isNotEmpty) {
        cancelCurrentBotResponse();
      }

      setState(() {
        currentText = result.recognizedWords;
        isSpeaking = result.recognizedWords.isNotEmpty;
      });
      
      speechTimer?.cancel();
      if (result.recognizedWords.isNotEmpty) {
        speechTimer = Timer(const Duration(seconds: 3), () {
          if (currentText.isNotEmpty) {
            sendToBackend(currentText);
            setState(() {
              currentText = "";
            });
          }
        });
      }
    }
  }

  void cancelCurrentBotResponse() {
    botResponseTimer?.cancel();
    currentResponseController?.close();
    currentResponseController = null;
    setState(() {
      isProcessingResponse = false;
      messages.removeWhere((m) => m['isTyping'] == 'true');
    });
  }

  Future<void> sendToBackend(String text) async {
    cancelCurrentBotResponse();
    addMessage('user', text);
    
    const String backendUrl = "https://rampoth.pythonanywhere.com/process_text";
    try {
      setState(() {
        isProcessingResponse = true;
      });

      var response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 200 && mounted) {
        var jsonResponse = json.decode(response.body);
        
        currentResponseController = StreamController<String>();
        String botResponse = jsonResponse['response'];
        
        addTypingMessage();
        
        List<String> words = botResponse.split(' ');
        int wordIndex = 0;
        
        botResponseTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
          if (!currentResponseController!.isClosed && mounted) {
            if (wordIndex < words.length) {
              currentResponseController!.add(words.sublist(0, wordIndex + 1).join(' '));
              wordIndex++;
            } else {
              timer.cancel();
              if (!currentResponseController!.isClosed) {
                currentResponseController!.close();
                removeTypingMessage();
                addMessage('bot', botResponse);
                setState(() {
                  isProcessingResponse = false;
                });
              }
            }
          } else {
            timer.cancel();
          }
        });
        
        currentResponseController!.stream.listen(
          (partialResponse) {
            if (mounted) {
              updateTypingMessage(partialResponse);
            }
          },
          onDone: () {
            if (mounted) {
              removeTypingMessage();
              setState(() {
                isProcessingResponse = false;
              });
            }
          },
        );
      } else {
        if (mounted) {
          addMessage('bot', 'Failed to communicate with the backend.');
          setState(() {
            isProcessingResponse = false;
          });
        }
      }
    } catch (e) {
      print("Error sending text to backend: $e");
      if (mounted) {
        addMessage('bot', 'Error processing your message. Please try again.');
        setState(() {
          isProcessingResponse = false;
        });
      }
    }
  }

  void addTypingMessage() {
    setState(() {
      messages.add({'sender': 'bot', 'text': '...', 'isTyping': 'true'});
    });
  }

  void updateTypingMessage(String text) {
    setState(() {
      int typingIndex = messages.indexWhere((m) => m['isTyping'] == 'true');
      if (typingIndex != -1) {
        messages[typingIndex]['text'] = text;
      }
    });
  }

  void removeTypingMessage() {
    setState(() {
      messages.removeWhere((m) => m['isTyping'] == 'true');
    });
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
        title: const Text("Interactive Bot"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(height * 0.01),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var message = messages[index];
                bool isBot = message['sender'] == 'bot';
                bool isTyping = message['isTyping'] == 'true';
                
                return ChatMessage(
                  text: message['text']!,
                  isBot: isBot,
                  isTyping: isTyping,
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(height * 0.012),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: height * 0.04,
                      vertical: height * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Center(
                      child: Text(
                        isSpeaking ? "Speaking..." : (currentText.isEmpty ? "Listening..." : currentText),
                        style: TextStyle(
                          fontSize: height * 0.0185,
                          color: isSpeaking ? Colors.blue : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}