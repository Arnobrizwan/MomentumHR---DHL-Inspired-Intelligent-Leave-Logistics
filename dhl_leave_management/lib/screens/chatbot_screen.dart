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
  
  // Gemini API key
  final String _geminiApiKey = 'AIzaSyBc0TRst4vZQ_NxX3-LWe0LMputs6dkOAQ';
  
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
          text: 'Hello! I\'m your DHL Leave Management Assistant. How can I help you today with your leave management queries?',
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
          
          // Add role-specific welcome message
          if (_userRole == 'HR') {
            _messages.add(
              ChatMessage(
                text: 'I see you\'re an HR administrator. You can ask me about employee leave criteria, leave balances, policy information, or how to manage leave requests.',
                isUser: false,
                timestamp: DateTime.now().add(const Duration(milliseconds: 500)),
              ),
            );
          } else {
            _messages.add(
              ChatMessage(
                text: 'I see you\'re an employee. You can ask me about your leave balances, leave policies, or how to submit leave requests.',
                isUser: false,
                timestamp: DateTime.now().add(const Duration(milliseconds: 500)),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Continue with default values if error occurs
      print('Error loading user info: $e');
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
      // Generate context about the user and system with enhanced prompt for detailed answers
      final context = '''
You are the DHL Leave Management Assistant, a helpful AI chatbot designed to assist with leave management questions. Always personalize your responses by addressing the user by name if available.

Current user: $_userName
User role: $_userRole
Current date: ${DateTime.now().toString().substring(0, 10)}

Always begin your response with "Okay, $_userName." when responding to a question.

DHL Leave Policy Details:
- Annual Leave: 14 days per year for regular employees, 21 days for managers, 28 days for directors
- Medical Leave: 14 days per year, requires medical certificate for 2+ days
- Emergency Leave: Up to 5 days per year for urgent personal or family matters
- Maternity Leave: 90 calendar days of paid leave, must be taken continuously, notify HR at least 30 days before expected delivery date
- Paternity Leave: 7 calendar days of paid leave, must be taken within one month of child's birth

${_userRole == 'HR' ? '''
HR-specific information (provide detailed answers):
- You can view and approve all leave applications in the system through the Leave Applications section
- You can run reports on leave balances for all employees through the Dashboard > Reports section
- You can modify leave policies and entitlements through Settings > Leave Policies
- You can check an employee's leave history by selecting their profile and viewing the Leave History tab
- You can override the system to grant special leave exceptions for special circumstances
- Emphasize that you don't have direct access to the live data when asked about specific numbers, but explain where they can find this information in the system

When answering HR queries, provide specific steps and menu paths for how to accomplish tasks in the system.
''' : '''
Employee-specific information (provide detailed answers):
- You need to submit leave requests at least 7 days in advance for planned leave
- Medical leave requires uploading a doctor's certificate within 2 days of returning
- Leave approval typically takes 1-2 business days
- You can cancel pending leave applications but not approved ones
- Your leave balance is visible on your dashboard under the My Leave Balance section
- Provide specific navigation steps for any system actions

When answering employee queries, be empathetic and provide specific step-by-step guidance.
'''}

Submission process:
1. Fill out leave application form with dates and reason
2. Submit for HR approval
3. Wait for notification of approval or rejection
4. If rejected, you can modify and resubmit or discuss with HR

Important considerations:
- Overlap: Leave requests may be rejected if they overlap with critical business periods
- Team coverage: Managers consider team coverage when approving leave
- Carry-over: Up to 5 days of annual leave can be carried over to the next year
- Encashment: Unused leave beyond 5 days can be encashed at year-end
- Record-keeping: All leave is tracked in the system for compliance and payroll

For any data-specific questions, explain that you don't have access to the live system data but you can guide them on how to find the information they need.

Make your responses detailed, professional, and specific to the user's role.
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
      print('Error getting response: $e');
    }
  }
  
  Future<String> _getGeminiResponse(String context, String userMessage) async {
    try {
      // URL for Gemini API - UPDATED to use gemini-2.0-flash
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey');
      
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
      
      // Make the actual HTTP request
      final response = await http.post(
        url, 
        body: requestBody, 
        headers: {'Content-Type': 'application/json'}
      );
      
      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          // Extract the text from the response
          if (jsonResponse['candidates'] != null && 
              jsonResponse['candidates'].isNotEmpty && 
              jsonResponse['candidates'][0]['content'] != null &&
              jsonResponse['candidates'][0]['content']['parts'] != null &&
              jsonResponse['candidates'][0]['content']['parts'].isNotEmpty) {
            return jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          }
        } catch (parseError) {
          print('Error parsing API response: $parseError');
          print('Response body: ${response.body}');
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
      }
      
      // Fallback responses
      return _getFallbackResponse(userMessage);
    } catch (e) {
      print('Error calling Gemini API: $e');
      return _getFallbackResponse(userMessage);
    }
  }
  
  String _getFallbackResponse(String userMessage) {
    final lowerCaseMessage = userMessage.toLowerCase();
    
    // Start responses with user's name
    final greeting = "Okay, $_userName. ";
    
    // Custom fallback responses based on the question
    if (_userRole == 'HR') {
      // HR-specific fallback responses
      if (lowerCaseMessage.contains('pending') && 
          (lowerCaseMessage.contains('leave') || lowerCaseMessage.contains('request')) && 
          (lowerCaseMessage.contains('how many') || lowerCaseMessage.contains('count'))) {
        return greeting + "As the DHL Leave Management Assistant, I don't have direct access to the live data to tell you the exact number of pending leave requests right now.\n\nHowever, as HR, you can easily check this in the system. Just log in and go to the \"Leave Applications\" section. You'll find a filter or status option to view all \"Pending\" requests. That will give you the real-time number of leave requests awaiting your approval.";
      }
      
      if (lowerCaseMessage.contains('maternity') && lowerCaseMessage.contains('leave')) {
        return greeting + "As HR, you have access to the full policy details, but here's a summary of the maternity leave policy at DHL:\n\nMaternity Leave: Employees are entitled to 90 calendar days of maternity leave.\n\n- This must be taken continuously\n- Employees should notify HR at least 30 days before expected delivery date\n- Medical documentation is required\n- Pay is 100% for the entire period\n- Position is guaranteed upon return\n- Extended unpaid leave may be available upon request\n\nYou can view the complete policy document in the HR portal under Policies > Leave > Maternity.";
      }
      
      if (lowerCaseMessage.contains('leave criteria') || 
          lowerCaseMessage.contains('eligibility') || 
          lowerCaseMessage.contains('policy')) {
        return greeting + "As an HR admin, you can view the complete leave criteria in the Settings > Leave Policies section. Here's a summary of our current policies:\n\n• Annual Leave: 14 days for regular employees, 21 days for managers, 28 days for directors\n• Medical Leave: 14 days per year, requires medical certificate for 2+ days\n• Emergency Leave: 5 days per year for urgent matters\n• Maternity Leave: 90 calendar days\n• Paternity Leave: 7 calendar days\n\nEligibility criteria vary by leave type and employment status. Full-time employees become eligible for all leave types after completing their probation period (typically 3 months).";
      }
      
      if (lowerCaseMessage.contains('report') || 
          lowerCaseMessage.contains('balance') || 
          lowerCaseMessage.contains('overview')) {
        return greeting + "You can generate comprehensive leave balance reports from the Dashboard by following these steps:\n\n1. Navigate to the Dashboard tab\n2. Click on the 'Reports' section in the sidebar\n3. Select 'Leave Balance Report' from the dropdown menu\n4. Use the filters to refine your search:\n   - Department (All, Operations, Finance, etc.)\n   - Date Range (Current Year, Last Quarter, Custom Period)\n   - Leave Type (All, Annual, Medical, etc.)\n5. Click 'Generate Report'\n\nThe system will produce a report showing all employees' leave balances matching your filters. You can export this to Excel or PDF using the download icons in the top right of the report view.";
      }
      
      if (lowerCaseMessage.contains('approve') || 
          lowerCaseMessage.contains('request')) {
        return greeting + "To approve leave requests, follow these steps:\n\n1. Go to the 'Leave Applications' tab in the main navigation\n2. You'll see a list of all leave applications with their status\n3. Use the filter dropdown to show only 'Pending' requests if needed\n4. Click on a specific request to view all details\n5. Review the information including:\n   - Employee name and ID\n   - Leave type and duration\n   - Reason provided\n   - Any attached documentation\n6. Click either 'Approve' or 'Reject' buttons\n7. If rejecting, you'll be prompted to provide a reason\n\nThe employee will receive an automatic notification once you take action.";
      }
    } else {
      // Employee-specific fallback responses
      if (lowerCaseMessage.contains('apply') || 
          lowerCaseMessage.contains('request')) {
        return greeting + "To apply for leave, follow these steps:\n\n1. Go to the Leave Applications tab in the sidebar\n2. Click on the '+' button in the bottom right corner\n3. Fill in the required details:\n   - Select leave type (Annual, Medical, Emergency, etc.)\n   - Choose start and end dates using the calendar\n   - Enter the reason for your leave request\n   - Upload any supporting documents if needed\n4. Review your application details\n5. Click 'Submit'\n\nYour request will be sent to HR for approval, and you'll receive a notification once it's processed. Remember to apply at least 7 days in advance for planned leave.";
      }
      
      if (lowerCaseMessage.contains('balance') || 
          lowerCaseMessage.contains('remaining')) {
        return greeting + "You can view your current leave balance by following these steps:\n\n1. Go to your Dashboard (home screen)\n2. Look for the 'My Leave Balance' section\n3. You'll see a breakdown of each leave type:\n   - Annual Leave: [Entitled] days per year, [Used] days so far, [Remaining] days available\n   - Medical Leave: 14 days total, with your current usage and balance\n   - Emergency Leave: 5 days total with remaining balance\n\nYour balance is automatically updated whenever a leave request is approved. If you believe there's an error in your balance calculation, please contact HR.";
      }
      
      if (lowerCaseMessage.contains('cancel') || 
          lowerCaseMessage.contains('withdraw')) {
        return greeting + "You can cancel a pending leave application by following these steps:\n\n1. Go to the Leave Applications tab in the sidebar\n2. Locate your application with 'Pending' status\n3. Click on it to open the details\n4. At the bottom of the screen, you'll see a 'Cancel Application' button\n5. Click the button and confirm your action\n\nPlease note that you can only cancel leave requests that are still in 'Pending' status. If your leave has already been approved and you need to cancel it, please contact HR directly as soon as possible.";
      }
      
      if (lowerCaseMessage.contains('maternity') && lowerCaseMessage.contains('leave')) {
        return greeting + "Here's information about DHL's maternity leave policy:\n\nEmployees are entitled to 90 calendar days of paid maternity leave. This benefit is available to all confirmed female employees (those who have completed probation).\n\nKey points:\n• 90 days of fully paid leave\n• Must be taken continuously (not in portions)\n• Notify your manager and HR at least 30 days before your expected delivery date\n• Submit medical documentation from your doctor\n• Your position will be held for you during your absence\n• You may be eligible for extended unpaid leave if needed\n\nTo apply, submit your request through the Leave Applications section with your expected delivery date and doctor's note.";
      }
    }
    
    // General fallback for any user
    if (lowerCaseMessage.contains('annual leave') || 
        lowerCaseMessage.contains('vacation')) {
      return greeting + "Here's the detailed information about annual leave at DHL:\n\n• Regular employees: 14 days per year\n• Managers: 21 days per year\n• Directors: 28 days per year\n\nImportant policies:\n• Leave requests should be submitted at least 7 days in advance\n• Approval depends on business needs and team coverage\n• You can carry forward up to 5 unused days to the next year\n• Remaining unused days beyond those 5 may be eligible for encashment\n• Leave is calculated on a calendar year basis (January-December)\n\nYou can check your current balance and apply for leave through the Leave Applications section of the system.";
    }
    
    if (lowerCaseMessage.contains('medical') || 
        lowerCaseMessage.contains('sick')) {
      return greeting + "Medical leave at DHL works as follows:\n\n• All employees are entitled to 14 days of paid medical leave per year\n• For 1-day absences: No medical certificate is required, but you must notify your supervisor\n• For 2+ days: A medical certificate from a registered doctor is mandatory\n• Medical certificates must be uploaded to the system within 2 days of returning to work\n• Notify your supervisor as soon as possible when taking medical leave\n• Extended medical leave beyond your allocation requires special approval\n\nTo report medical leave, you can call your supervisor and then formalize the leave request in the system when you return.";
    }
    
    if (lowerCaseMessage.contains('emergency')) {
      return greeting + "Emergency leave details at DHL:\n\n• 5 days of emergency leave are available per year for urgent personal or family matters\n• This covers situations like:\n  - Family emergencies\n  - Bereavement\n  - Household emergencies (flooding, fire, etc.)\n  - Other unexpected critical situations\n\n• No advance notice is required, but you should notify your supervisor as soon as possible\n• Documentation may be requested depending on the situation\n• If you need more than your allocation, contact HR to discuss your options\n\nTo report emergency leave, call your supervisor immediately and then submit the leave request in the system when possible.";
    }
    
    if (lowerCaseMessage.contains('status')) {
      return greeting + "You can check the status of your leave applications by following these steps:\n\n1. Go to the Leave Applications tab in the sidebar\n2. You'll see a list of all your leave requests with their current status\n3. The status will be one of the following:\n   - Pending: Still waiting for HR review\n   - Approved: Your leave request has been approved\n   - Rejected: Your request was denied (with a reason provided)\n\n4. Click on any application to view more details, including approval comments or rejection reasons\n\nYou'll also receive email notifications whenever your leave status changes.";
    }
    
    // Default response if no specific pattern is matched
    return greeting + "I understand you're asking about \"" + userMessage + "\". As your DHL Leave Management Assistant, I can help with questions about leave policies, application processes, and status checks. Could you please provide more specific details about what you'd like to know regarding leave management?";
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
        title: Row(
          children: [
            Container(
              height: 28,
              width: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00), // DHL Yellow
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Image.asset(
                  'assets/DHL_Express_logo_rgb.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Leave Assistant'),
          ],
        ),
        backgroundColor: const Color(0xFFD40511), // DHL Red
        actions: [
          if (_userRole.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(
                  _userRole,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: _userRole == 'HR' 
                    ? Colors.blue[700] 
                    : Colors.green[700],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            // Chat messages
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: 0.5,
                            child: Container(
                              height: 60,
                              width: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCC00), // DHL Yellow
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/DHL_Express_logo_rgb.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD40511),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Assistant is typing...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Message input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type your question...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send),
                            color: const Color(0xFFD40511),
                            onPressed: _sendMessage,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00), // DHL Yellow
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "DHL",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFFD40511) // DHL Red
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 10,
                          color: message.isUser 
                              ? Colors.white.withOpacity(0.7) 
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: message.isUser 
                                ? Colors.white.withOpacity(0.7) 
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _userRole == 'HR' ? Colors.blue[700] : Colors.blueGrey,
              radius: 18,
              child: Text(
                _userName.isNotEmpty ? _userName.substring(0, 1).toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
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