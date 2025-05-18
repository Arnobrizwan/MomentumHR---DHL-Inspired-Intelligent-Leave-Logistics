import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dhl_leave_management/screens/password_reset_screen.dart';

class FirstTimePasswordChangeScreen extends StatefulWidget {
  final String email;
  final String? actionCode;

  const FirstTimePasswordChangeScreen({
    Key? key,
    required this.email,
    this.actionCode,
  }) : super(key: key);

  @override
  State<FirstTimePasswordChangeScreen> createState() => _FirstTimePasswordChangeScreenState();
}

class _FirstTimePasswordChangeScreenState extends State<FirstTimePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordChanged = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'New passwords do not match.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('No authenticated user found.');
      }
      
      // Create credentials with the user's email and current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: widget.email,
        password: _currentPasswordController.text,
      );
      
      // Re-authenticate the user
      await user.reauthenticateWithCredential(credential);
      
      // Change the password
      await user.updatePassword(_newPasswordController.text);
      
      setState(() {
        _isLoading = false;
        _passwordChanged = true;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'wrong-password':
            _errorMessage = 'The current password is incorrect.';
            break;
          case 'user-mismatch':
            _errorMessage = 'The provided credentials do not match the current user.';
            break;
          case 'user-not-found':
            _errorMessage = 'No user found with this email.';
            break;
          case 'invalid-credential':
            _errorMessage = 'Invalid credentials. Please try again.';
            break;
          case 'weak-password':
            _errorMessage = 'The new password is too weak.';
            break;
          case 'requires-recent-login':
            _errorMessage = 'This operation requires recent authentication. Please log in again.';
            break;
          default:
            _errorMessage = e.message ?? 'Failed to change password.';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Top yellow banner
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: const Color(0xFFFFCC00), // DHL Yellow
                    ),
                    
                    Expanded(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // DHL Logo
                              Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(bottom: 32),
                                child: Image.asset(
                                  'assets/DHL_Express_logo_rgb.png',
                                  height: 70,
                                ),
                              ),
                              
                              // Title
                              const Text(
                                'Change Your Password',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              
                              _passwordChanged
                                  ? _buildSuccessMessage()
                                  : _buildChangePasswordForm(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.grey[200],
                      child: Column(
                        children: [
                          const Text(
                            'Version 1.0.0',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '© 2025 DHL Express. All rights reserved.',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Password Changed Successfully',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your password has been changed successfully. You can now continue using your account with your new password.',
                style: TextStyle(
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD40511), // DHL Red
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            'Continue to Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Please change your password to continue.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Current Password Field
          TextFormField(
            controller: _currentPasswordController,
            decoration: InputDecoration(
              hintText: 'Current Password',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD40511)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF666666),
                ),
                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
            ),
            obscureText: _obscureCurrentPassword,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please enter your current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // New Password Field
          TextFormField(
            controller: _newPasswordController,
            decoration: InputDecoration(
              hintText: 'New Password',
              prefixIcon: const Icon(Icons.lock, color: Color(0xFFD40511)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF666666),
                ),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            obscureText: _obscureNewPassword,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please enter a new password';
              }
              if (v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              if (v == _currentPasswordController.text) {
                return 'New password must be different from current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              hintText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD40511)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF666666),
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            obscureText: _obscureConfirmPassword,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your new password';
              }
              if (v != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          
          // Error Message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Change Password Button
          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD40511), // DHL Red
              disabledBackgroundColor: const Color(0xFFD40511).withOpacity(0.6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // Cancel Button - Skip for now
          TextButton(
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text(
                    'Skip Password Change?',
                    style: TextStyle(
                      color: Color(0xFFD40511),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: const Text(
                    'It is recommended to change your password for security reasons. Are you sure you want to skip this step?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF666666),
                      ),
                      child: const Text('No, I\'ll Change It'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD40511),
                        elevation: 0,
                      ),
                      child: const Text('Yes, Skip For Now'),
                    ),
                  ],
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text(
              'Skip for Now',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}