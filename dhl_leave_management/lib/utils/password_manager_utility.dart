import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/screens/password_reset_screen.dart';
import 'package:dhl_leave_management/screens/first_time_password_change_screen.dart';

// This class is for handling password-related functionality
class PasswordManager {
  
  // Method to navigate to ForgotPassword screen
  static void navigateToForgotPassword(BuildContext context, [String? email]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          email: email,
          isForgotPassword: true,
        ),
      ),
    );
  }
  
  // Method to navigate to first-time password change screen
  static void navigateToFirstTimePasswordChange(BuildContext context, String email) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FirstTimePasswordChangeScreen(
          email: email,
        ),
      ),
    );
  }
  
  // Method to check if a user should change password (e.g., if it's been 90 days)
  static Future<bool> shouldChangePassword(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists) {
        // If the user doesn't exist in Firestore, they should change their password
        return true;
      }
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // Check if passwordLastChanged field exists
      if (!data.containsKey('passwordLastChanged')) {
        return true;
      }
      
      Timestamp lastChanged = data['passwordLastChanged'] as Timestamp;
      DateTime lastChangedDate = lastChanged.toDate();
      DateTime now = DateTime.now();
      
      // Calculate the difference in days
      int daysSinceLastChange = now.difference(lastChangedDate).inDays;
      
      // If it's been more than 90 days, they should change their password
      return daysSinceLastChange > 90;
    } catch (e) {
      // If there's an error, require password change as a precaution
      print('Error checking password status: $e');
      return true;
    }
  }
  
  // Method to update password change timestamp
  static Future<void> updatePasswordChangeTimestamp(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'passwordLastChanged': Timestamp.now(),
      });
      
      print('Password change timestamp updated successfully');
    } catch (e) {
      print('Error updating password change timestamp: $e');
    }
  }
  
  // Method to handle password reset via email
  static Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: email.trim(),
    );
  }
  
  // Method to validate password strength
  static String? validatePasswordStrength(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter a password';
    }
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!hasUppercase) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!hasDigits) {
      return 'Password must contain at least one number';
    }
    
    if (!hasSpecialCharacters) {
      return 'Password must contain at least one special character';
    }
    
    return null; // Password is valid
  }
  
  // Method to check if the provided password is one of commonly used passwords
  static bool isCommonPassword(String password) {
    List<String> commonPasswords = [
      'password', 'password123', '123456', 'qwerty', 'admin',
      'welcome', 'welcome123', 'letmein', 'monkey', 'abc123',
    ];
    
    return commonPasswords.contains(password.toLowerCase());
  }
}

// Extension to use in LoginScreen
extension LoginScreenPasswordFunctionality on State {
  void showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Color(0xFFD40511),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How would you like to reset your password?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Options for password reset
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                PasswordManager.navigateToForgotPassword(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD40511),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              ),
              child: const Text('Email Reset Link'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF666666),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}