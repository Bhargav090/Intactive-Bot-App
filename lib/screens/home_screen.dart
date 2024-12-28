import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String defaultQuestion = 'What makes the internet essential?';
  bool isListening = false;
  bool isSpeaking = false;
  bool isProcessingResponse = false;
  bool isBotSpeaking = false;
  bool hasAskedInitialQuestion = false;
  String currentText = "";
  String botResponse = "";
  String lastRecognizedText = "";
  Timer? speechTimer;
  stt.SpeechToText speech = stt.SpeechToText();
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    initializeSpeech();
    initializeTts();
    Future.delayed(const Duration(milliseconds: 1000), () {
      speakInitialQuestion();
    });
  }

  @override
  void dispose() {
    speechTimer?.cancel();
    speech.stop();
    flutterTts.stop();
    super.dispose();
  }

  Future<void> speakInitialQuestion() async {
    setState(() {
      isBotSpeaking = true;
    });
    await flutterTts.speak(defaultQuestion);
  }

  Future<void> initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    
    flutterTts.setCompletionHandler(() {
      setState(() {
        isBotSpeaking = false;
        if (!hasAskedInitialQuestion) {
          hasAskedInitialQuestion = true;
          startContinuousListening();
        }
      });
    });
  }

  Future<void> initializeSpeech() async {
    bool available = await speech.initialize(
      onStatus: (status) async {
        if (status == 'done' || status == 'notListening') {
          await Future.delayed(const Duration(milliseconds: 50));
          if (mounted && hasAskedInitialQuestion) {
            startContinuousListening();
          }
        }
      },
      onError: (error) async {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted && hasAskedInitialQuestion) {
          startContinuousListening();
        }
      },
    );
    
    if (available && !hasAskedInitialQuestion) {
      setState(() {
        isListening = false;
      });
    }
  }

  void startContinuousListening() async {
    if (!speech.isListening && mounted && hasAskedInitialQuestion) {
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
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted && hasAskedInitialQuestion) {
          startContinuousListening();
        }
      }
    }
  }

  void handleSpeechResult(result) {
    if (mounted) {
      String recognizedWords = result.recognizedWords;
      
      if (recognizedWords.isNotEmpty) {
        lastRecognizedText = recognizedWords;
      }

      if (isBotSpeaking && recognizedWords.isNotEmpty) {
        flutterTts.stop();
        setState(() {
          isBotSpeaking = false;
          botResponse = "";
          currentText = recognizedWords;
        });
      }

      setState(() {
        currentText = recognizedWords;
        isSpeaking = recognizedWords.isNotEmpty;
      });
      
      speechTimer?.cancel();
      
      if (recognizedWords.isNotEmpty) {
        speechTimer = Timer(const Duration(seconds: 2), () {
          if (lastRecognizedText.isNotEmpty) {
            sendToBackend(lastRecognizedText);
            setState(() {
              currentText = "";
              lastRecognizedText = "";
            });
          }
        });
      }
    }
  }

  Future<void> sendToBackend(String text) async {
    if (isBotSpeaking) {
      await flutterTts.stop();
      setState(() {
        isBotSpeaking = false;
      });
    }

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
        String responseText = jsonResponse['response'];
        
        setState(() {
          botResponse = responseText;
          isBotSpeaking = true;
        });
        
        await flutterTts.speak(responseText);
      }
      
      setState(() {
        isProcessingResponse = false;
      });
    } catch (e) {
      setState(() {
        isProcessingResponse = false;
        botResponse = "Error processing your message. Please try again.";
      });
      await flutterTts.speak(botResponse);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Interactive Bot",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 181, 133, 249)
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 255, 255, 255),
              const Color.fromARGB(255, 51, 36, 59),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.question_answer_rounded,
                          size: 40,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          defaultQuestion,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 103, 103, 103),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !hasAskedInitialQuestion
                            ? Colors.green.withOpacity(0.2)
                            : isSpeaking
                                ? Colors.blue.withOpacity(0.2)
                                : isBotSpeaking
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                      ),
                      child: Icon(
                        !hasAskedInitialQuestion
                            ? Icons.record_voice_over
                            : isSpeaking
                                ? Icons.mic
                                : isBotSpeaking
                                    ? Icons.speaker
                                    : Icons.hearing,
                        size: 40,
                        color: !hasAskedInitialQuestion
                            ? Colors.green
                            : isSpeaking
                                ? Colors.blue
                                : isBotSpeaking
                                    ? Colors.green
                                    : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      !hasAskedInitialQuestion
                          ? "Bot is asking..."
                          : isSpeaking
                              ? "Speaking..."
                              : isBotSpeaking
                                  ? "Bot is responding..."
                                  : "Listening...",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: !hasAskedInitialQuestion
                            ? Colors.green
                            : isSpeaking
                                ? Colors.blue
                                : isBotSpeaking
                                    ? Colors.green
                                    : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}