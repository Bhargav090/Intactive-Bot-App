import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class Speech {
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
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  final Function(void Function()) setState;
  final Function(String) showError;
  final bool mounted;
  Timer? statusUpdateTimer;

  Speech({
    required this.setState,
    required this.showError,
    required this.mounted,
  });

  Future<void> initialize() async {
    await initializeSpeech();
    await initializeTts();
    await Future.delayed(const Duration(milliseconds: 1000));
    await speakInitialQuestion();
  }

  Future<void> speakInitialQuestion() async {
    try {
      setState(() {
        isBotSpeaking = true;
      });
      await flutterTts.speak(defaultQuestion);
    } catch (e) {
      print("Error speaking initial question: $e");
      showError("Error starting conversation. Please restart the app.");
    }
  }

  Future<void> initializeTts() async {
    try {
      await flutterTts.setLanguage("en-US");
      await flutterTts.setSpeechRate(0.4);
      
      flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            isBotSpeaking = false;
            if (!hasAskedInitialQuestion) {
              hasAskedInitialQuestion = true;
              startContinuousListening();
            }
          });
        }
      });

      flutterTts.setErrorHandler((msg) {
        print("TTS error: $msg");
        showError("Voice output error. Please check your device settings.");
      });
    } catch (e) {
      print("Error initializing TTS: $e");
      showError("Error initializing voice output. Please restart the app.");
    }
  }

  Future<void> initializeSpeech() async {
    try {
      bool available = await speech.initialize(
        onStatus: (status) async {
          print("Speech status: $status");
          if (status == 'done' || status == 'notListening') {
            await Future.delayed(const Duration(milliseconds: 50));
            if (mounted && hasAskedInitialQuestion) {
              startContinuousListening();
            }
          }
        },
        onError: (error) async {
          print("Speech error: $error");
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
      } else if (!available) {
        showError("Speech recognition not available on this device.");
      }
    } catch (e) {
      print("Error initializing speech: $e");
      showError("Error initializing voice input. Please check your permissions.");
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
          isSpeaking = false;
        });
      } catch (e) {
        print("Error starting listening: $e");
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

      statusUpdateTimer?.cancel();

      if (isBotSpeaking && recognizedWords.isNotEmpty) {
        flutterTts.stop();
        setState(() {
          isBotSpeaking = false;
          botResponse = "";
          currentText = recognizedWords;
          isSpeaking = true;
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
            setState(() {
              isSpeaking = false;
            });
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
    if (text.trim().isEmpty) {
      print("Empty text detected, skipping backend call");
      return;
    }

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
        isSpeaking = false;
      });

      var response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({'text': text}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request took too long');
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          var jsonResponse = json.decode(response.body);
          String responseText = jsonResponse['response'];
          
          if (responseText.trim().isEmpty) {
            throw Exception('Empty response from backend');
          }

          setState(() {
            botResponse = responseText;
            isBotSpeaking = true;
            isSpeaking = false; 
          });
          
          await flutterTts.speak(responseText);
        } catch (e) {
          print("JSON parsing error: $e");
          throw Exception('Invalid response format');
        }
      } else {
        throw HttpException('Backend returned ${response.statusCode}');
      }
    } on TimeoutException {
      print("Request timed out");
      showError("Request took too long. Please check your internet connection.");
    } on HttpException catch (e) {
      print("HTTP error: $e");
      showError("Server error. Please try again later.");
    } catch (e) {
      print("Error details: $e");
      showError("Connection error. Please check your internet and try again.");
    } finally {
      if (mounted) {
        setState(() {
          isProcessingResponse = false;
        });
      }
    }
  }

  void dispose() {
    speechTimer?.cancel();
    speech.stop();
    flutterTts.stop();
  }
}