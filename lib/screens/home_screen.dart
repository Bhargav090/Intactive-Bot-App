import 'package:flutter/material.dart';
import 'package:intractivebot/screens/speech.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Speech speechService;

  @override
  void initState() {
    super.initState();
    speechService = Speech(
      setState: setState,
      showError: showError,
      mounted: mounted,
    );
    speechService.initialize();
  }

  @override
  void dispose() {
    speechService.dispose();
    super.dispose();
  }

  void showError(String message) {
    if (!mounted) return;
    
    setState(() {
      speechService.botResponse = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
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
                          speechService.defaultQuestion,
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
                        color: !speechService.hasAskedInitialQuestion
                            ? Colors.green.withOpacity(0.2)
                            : speechService.isSpeaking
                                ? Colors.blue.withOpacity(0.2)
                                : speechService.isBotSpeaking
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                      ),
                      child: Icon(
                        !speechService.hasAskedInitialQuestion
                            ? Icons.record_voice_over
                            : speechService.isSpeaking
                                ? Icons.mic
                                : speechService.isBotSpeaking
                                    ? Icons.speaker
                                    : Icons.hearing,
                        size: 40,
                        color: !speechService.hasAskedInitialQuestion
                            ? Colors.green
                            : speechService.isSpeaking
                                ? Colors.blue
                                : speechService.isBotSpeaking
                                    ? Colors.green
                                    : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      !speechService.hasAskedInitialQuestion
                          ? "Bot is asking..."
                          : speechService.isSpeaking
                              ? "Speaking..."
                              : speechService.isBotSpeaking
                                  ? "Bot is responding..."
                                  : "Listening...",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: !speechService.hasAskedInitialQuestion
                            ? Colors.green
                            : speechService.isSpeaking
                                ? Colors.blue
                                : speechService.isBotSpeaking
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