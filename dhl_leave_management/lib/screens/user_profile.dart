import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _isHR = false;
  String _userType = '';
  String _email = '';
  String _name = '';
  String _department = '';
  String _employeeId = '';
  String _userId = '';
  String _createdAt = '';
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }
      
      _userId = user.uid;
      _email = user.email ?? '';
      
      // Get user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final userData = userDoc.data() ?? {};
      final userType = userData['userType'] ?? 'EMPLOYEE';
      final name = userData['name'] ?? 'User';
      final department = userData['department'] ?? 'HR';
      final createdAt = userData['createdAt'] as Timestamp?;
      
      setState(() {
        _userType = userType;
        _isHR = userType == 'HR_ADMIN';
        _name = name;
        _nameController.text = name;
        _department = department;
        _departmentController.text = department;
        
        if (createdAt != null) {
          // Format date to readable string
          _createdAt = _formatTimestamp(createdAt);
        }
      });
      
      // If we have an employeeId in the document, store it
      if (userData.containsKey('employeeId') && userData['employeeId'] != null) {
        setState(() {
          _employeeId = userData['employeeId'];
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final updateData = {
        'name': _nameController.text,
        'updatedAt': Timestamp.now(),
      };
      
      // Only update department if not HR
      if (!_isHR) {
        updateData['department'] = _departmentController.text;
      }
      
      // Update user document
      await _firestore.collection('users').doc(_userId).update(updateData);
      
      setState(() {
        _name = _nameController.text;
        if (!_isHR) {
          _department = _departmentController.text;
        }
        _isEditing = false;
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showDocumentDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD40511),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD40511),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
  
  void _showPrivacyPolicy() {
    _showDocumentDialog(
      'Privacy Policy',
      'DHL Express Privacy Policy\n\n'
      'Last updated: May 18, 2025\n\n'
      'DHL Express ("we," "our," or "us") respects your privacy and is committed to protecting your personal data. This Privacy Policy explains how we collect, use, and share information about you when you use our Employee Leave Management System.\n\n'
      '1. INFORMATION WE COLLECT\n\n'
      'We collect information that you provide directly to us, such as your name, email address, employee ID, department, and other information you choose to provide.\n\n'
      '2. HOW WE USE YOUR INFORMATION\n\n'
      'We use the information we collect to:\n'
      '• Provide, maintain, and improve our services\n'
      '• Process and manage leave requests\n'
      '• Communicate with you about your account and leave status\n'
      '• Respond to your comments, questions, and requests\n'
      '• Comply with applicable laws and regulations\n\n'
      '3. DATA SECURITY\n\n'
      'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet or electronic storage is 100% secure.\n\n'
      '4. CONTACT US\n\n'
      'If you have any questions about this Privacy Policy, please contact your HR department.'
    );
  }
  
  void _showTermsOfService() {
    _showDocumentDialog(
      'Terms of Service',
      'DHL Express Terms of Service\n\n'
      'Last updated: May 18, 2025\n\n'
      'Welcome to the DHL Express Employee Leave Management System. By accessing or using our system, you agree to be bound by these Terms of Service.\n\n'
      '1. ACCEPTANCE OF TERMS\n\n'
      'By accessing or using the DHL Express Employee Leave Management System, you agree to these Terms of Service and to any additional terms and conditions that may apply.\n\n'
      '2. USE OF THE SYSTEM\n\n'
      'You may use the system only for legitimate purposes related to your employment with DHL Express. You agree not to use the system for any illegal or unauthorized purpose.\n\n'
      '3. ACCOUNT SECURITY\n\n'
      'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to notify your HR department immediately of any unauthorized use of your account.\n\n'
      '4. CONTACT US\n\n'
      'If you have any questions about these Terms, please contact your HR department.'
    );
  }
  
  void _showHelpInfo() {
    _showDocumentDialog(
      'Need Help?',
      'Contact HR Department\n\n'
      'If you need assistance with the DHL Leave Management System, please contact your HR department through one of the following channels:\n\n'
      '• Email: hr@dhl.com\n'
      '• Phone: +1-800-123-4567\n'
      '• Office: Visit the HR desk during office hours\n\n'
      'Operating Hours:\n'
      'HR Department is available Monday-Friday, 9:00 AM - 5:00 PM.'
    );
  }
  
  void _showAboutInfo() {
    _showDocumentDialog(
      'About',
      'DHL Leave Management System\n'
      'Version 1.0.0\n\n'
      'This application is designed to streamline the leave management process for DHL Express employees worldwide. It allows employees to request time off, check their leave balances, and track approval status.\n\n'
      'Copyright © 2025 DHL Express. All rights reserved.'
    );
  }
  
  Future<void> _changePassword() async {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    final formKey = GlobalKey<FormState>();
    bool isChanging = false;
    String? errorMessage;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Change Password',
                style: TextStyle(
                  color: Color(0xFFD40511),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD40511)),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFFD40511)),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD40511)),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null) ...[
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
                                errorMessage,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isChanging
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() {
                              isChanging = true;
                              errorMessage = null;
                            });
                            
                            try {
                              // Get current user
                              final user = _auth.currentUser;
                              if (user == null || _email.isEmpty) {
                                setState(() {
                                  isChanging = false;
                                  errorMessage = 'User not authenticated';
                                });
                                return;
                              }
                              
                              // Create credential with current password
                              final credential = EmailAuthProvider.credential(
                                email: _email,
                                password: currentPasswordController.text,
                              );
                              
                              // Re-authenticate user
                              await user.reauthenticateWithCredential(credential);
                              
                              // Update password
                              await user.updatePassword(newPasswordController.text);
                              
                              // Update passwordLastChanged in Firestore
                              await _firestore.collection('users').doc(_userId).update({
                                'passwordLastChanged': Timestamp.now(),
                              });
                              
                              // Close dialog and show success message
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              setState(() {
                                isChanging = false;
                                if (e.code == 'wrong-password') {
                                  errorMessage = 'Current password is incorrect';
                                } else {
                                  errorMessage = e.message;
                                }
                              });
                            } catch (e) {
                              setState(() {
                                isChanging = false;
                                errorMessage = e.toString();
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD40511), // DHL Red
                  ),
                  child: isChanging
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
        foregroundColor: Colors.white,
        actions: [
          // Edit/Save Button
          if (!_isLoading)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_isEditing) {
                        _updateProfile();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
              tooltip: _isEditing ? 'Save' : 'Edit',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD40511), // DHL Red
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header with Avatar
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFFD40511), // DHL Red
                            child: Text(
                              _name.isNotEmpty
                                  ? _name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isHR ? 'HR Administrator' : 'Employee',
                            style: TextStyle(
                              color: _isHR ? const Color(0xFFD40511) : Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_createdAt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Account created: $_createdAt',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // User Information Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Name Field
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.person, color: Color(0xFFD40511)),
                              ),
                              enabled: _isEditing,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Email Field (read-only)
                            TextFormField(
                              initialValue: _email,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.email, color: Color(0xFFD40511)),
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 16),
                            
                            // Department Field
                            TextFormField(
                              controller: _departmentController,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.business, color: Color(0xFFD40511)),
                              ),
                              enabled: _isEditing && !_isHR, // HR can't edit their department
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your department';
                                }
                                return null;
                              },
                            ),
                            if (_employeeId.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              
                              // Employee ID Field (read-only)
                              TextFormField(
                                initialValue: _employeeId,
                                decoration: InputDecoration(
                                  labelText: 'Employee ID',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.badge, color: Color(0xFFD40511)),
                                ),
                                enabled: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Account Actions Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Change Password Button
                            ListTile(
                              leading: const Icon(Icons.lock, color: Color(0xFFD40511)),
                              title: const Text('Change Password'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _changePassword,
                            ),
                            const Divider(height: 1),
                            
                            // Logout Button
                            ListTile(
                              leading: const Icon(Icons.exit_to_app, color: Color(0xFFD40511)),
                              title: const Text('Logout'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _logout,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // App Information Card
                    Card(
                      elevation: 1,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'About',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.info_outline, color: Colors.grey),
                              title: const Text('DHL Leave Management System'),
                              subtitle: const Text('Version 1.0.0'),
                              onTap: _showAboutInfo,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.support_agent, color: Colors.grey),
                              title: const Text('Need Help?'),
                              subtitle: const Text('Contact HR Department'),
                              onTap: _showHelpInfo,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.policy, color: Colors.grey),
                              title: const Text('Privacy Policy'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _showPrivacyPolicy,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.description, color: Colors.grey),
                              title: const Text('Terms of Service'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _showTermsOfService,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Copyright
                    const Center(
                      child: Text(
                        '© 2025 DHL Express. All rights reserved.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}