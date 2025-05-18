import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/services/auth_service.dart';
import 'package:dhl_leave_management/services/firebase_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  String _userName = '';
  String _userRole = '';
  
  List<ChatMessage> _messages = [];
  
  // Replace with your actual Gemini API key
  final String _geminiApiKey = 'YOUR_GEMINI_API_KEY';
  
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _addInitialBotMessage();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _addInitialBotMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Hello! I\'m your DHL Leave Management Assistant. How can I help you today?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }
  
  Future<void> _loadUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['name'] ?? 'User';
            _userRole = userDoc.data()?['userType'] == 'HR_ADMIN' ? 'HR' : 'Employee';
          });
        }
      }
    } catch (e) {
      // Continue with default values if error occurs
    }
  }
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    // Add user message to chat
    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });
    
    _messageController.clear();
    
    // Scroll to bottom
    _scrollToBottom();
    
    try {
      // Generate context about the user and system
      final context = '''
You are the DHL Leave Management Assistant, a helpful AI chatbot designed to assist with leave management questions.
Current user: $_userName
User role: $_userRole
Current date: ${DateTime.now().toString().substring(0, 10)}
DHL Leave Policy:
- Annual Leave: 14 days per year
- Medical Leave: Requires certificate for 2+ days
- Emergency Leave: Up to 3 days per year
Submission process:
1. Fill out leave application form
2. Submit at least 7 days in advance for planned leave
3. Wait for approval from HR
''';
      
      // Get response from Gemini API
      final response = await _getGeminiResponse(context, message);
      
      setState(() {
        _isLoading = false;
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      
      // Scroll to bottom again after response
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error while processing your request. Please try again later.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      
      _scrollToBottom();
    }
  }
  
  Future<String> _getGeminiResponse(String context, String userMessage) async {
    try {
      // For this implementation, we'll use a simplified version
      // In a real app, you'd call the actual Gemini API
      
      // URL for Gemini API
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_geminiApiKey');
      
      // Request body
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': '$context\n\nUser question: $userMessage'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        }
      });
      
      // For demonstration, we'll simulate a response
      // In a real app, you'd make an actual HTTP request:
      // final response = await http.post(url, body: requestBody, headers: {'Content-Type': 'application/json'});
      
      // Simulate common leave-related questions
      if (userMessage.toLowerCase().contains('annual leave') || userMessage.toLowerCase().contains('vacation')) {
        return 'Annual leave at DHL is 14 days per year. You need to apply at least 7 days in advance for planned leave. Would you like me to help you apply for leave?';
      } else if (userMessage.toLowerCase().contains('medical leave') || userMessage.toLowerCase().contains('sick')) {
        return 'Medical leave requires a doctor\'s certificate for absences of 2 or more days. No prior notice is required, but you should inform your supervisor as soon as possible.';
      } else if (userMessage.toLowerCase().contains('emergency')) {
        return 'Emergency leave is limited to 3 days per year for urgent personal or family matters. Please notify your supervisor as soon as possible.';
      } else if (userMessage.toLowerCase().contains('apply') || userMessage.toLowerCase().contains('application')) {
        return 'To apply for leave, go to the "Apply for Leave" section from your dashboard. Fill in the required details including leave type, dates, and reason. Your request will be sent to HR for approval.';
      } else if (userMessage.toLowerCase().contains('status') || userMessage.toLowerCase().contains('approved')) {
        return 'You can check the status of your leave applications on your dashboard under "My Leave Applications". The status will show as Pending, Approved, or Rejected.';
      } else if (userMessage.toLowerCase().contains('cancel')) {
        return 'You can cancel pending leave applications from your dashboard. Navigate to "My Leave Applications", find the pending request, and click on "Cancel Application".';
      } else if (userMessage.toLowerCase().contains('balance') || userMessage.toLowerCase().contains('remaining')) {
        return 'Your leave balance is shown on your dashboard. If you\'re an employee, you can see your remaining leave days for each category. HR administrators can view leave balances for all employees.';
      } else {
        return 'I understand you\'re asking about "${userMessage}". As your leave management assistant, I can help with questions about leave policies, application process, and status checks. Could you please provide more specific details about your leave-related query?';
      }
    } catch (e) {
      return 'Sorry, I encountered an error connecting to the AI service. Please try again later.';
    }
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DHL Assistant'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: const Color(0xFFD40511), // DHL Red
                  mini: true,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: const Color(0xFFD40511), // DHL Red
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/a/ac/DHL_Logo.svg',
                width: 20,
                height: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFFD40511).withOpacity(0.9) // DHL Red
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser ? Colors.white.withOpacity(0.7) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Text(
                _userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}