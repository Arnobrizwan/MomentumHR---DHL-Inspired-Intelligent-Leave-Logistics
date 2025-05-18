import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) throw Exception('No authenticated user found.');

      final credential = EmailAuthProvider.credential(
        email: widget.email,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
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
            _errorMessage = 'The credentials do not match the current user.';
            break;
          case 'user-not-found':
            _errorMessage = 'No user found with this email.';
            break;
          case 'invalid-credential':
            _errorMessage = 'Invalid credentials.';
            break;
          case 'weak-password':
            _errorMessage = 'The new password is too weak.';
            break;
          case 'requires-recent-login':
            _errorMessage = 'This requires recent login. Please re-login.';
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
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 15,
                      color: const Color(0xFFFFCC00),
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
                              Container(
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(bottom: 32),
                                child: Image.asset(
                                  'assets/DHL_Express_logo_rgb.png',
                                  height: 70,
                                ),
                              ),
                              const Text(
                                'Change Password',
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.grey[200],
                      child: Column(
                        children: const [
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '© 2025 DHL Express. All rights reserved.',
                            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
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
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
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
                'You can now use your new password to continue using your account.',
                style: TextStyle(color: Colors.grey[800]),
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
            backgroundColor: const Color(0xFFD40511),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          ),
          child: const Text(
            'Continue to Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
            'Update your password below.',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildPasswordField(
            controller: _currentPasswordController,
            hint: 'Current Password',
            obscure: _obscureCurrentPassword,
            toggle: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
            icon: Icons.lock_outline,
            validator: (v) => v == null || v.isEmpty ? 'Please enter your current password' : null,
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _newPasswordController,
            hint: 'New Password',
            obscure: _obscureNewPassword,
            toggle: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            icon: Icons.lock,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a new password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              if (v == _currentPasswordController.text) return 'New password must be different';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmPasswordController,
            hint: 'Confirm New Password',
            obscure: _obscureConfirmPassword,
            toggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            icon: Icons.lock_outline,
            validator: (v) =>
                v != _newPasswordController.text ? 'Passwords do not match' : null,
          ),
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
          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD40511),
              disabledBackgroundColor: const Color(0xFFD40511).withOpacity(0.6),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFFD40511)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF666666)),
          onPressed: toggle,
        ),
      ),
    );
  }
}