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
      
      final userType = userDoc.data()?['userType'] ?? 'EMPLOYEE';
      final employeeId = userDoc.data()?['employeeId'] ?? '';
      final name = userDoc.data()?['name'] ?? 'User';
      
      setState(() {
        _userType = userType;
        _isHR = userType == 'HR_ADMIN';
        _name = name;
        _nameController.text = name;
      });
      
      if (employeeId.isNotEmpty) {
        // Get employee document for additional details
        final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
        if (employeeDoc.exists) {
          final department = employeeDoc.data()?['department'] ?? '';
          
          setState(() {
            _employeeId = employeeId;
            _department = department;
            _departmentController.text = department;
          });
        }
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
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update user document
      await _firestore.collection('users').doc(_userId).update({
        'name': _nameController.text,
        'updatedAt': Timestamp.now(),
      });
      
      // Update employee document if exists
      if (_employeeId.isNotEmpty) {
        await _firestore.collection('employees').doc(_employeeId).update({
          'name': _nameController.text,
          'department': _departmentController.text,
          'updatedAt': Timestamp.now(),
        });
      }
      
      setState(() {
        _name = _nameController.text;
        _department = _departmentController.text;
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
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
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
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // User Information Card
                    Card(
                      elevation: 2,
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
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
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
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 16),
                            
                            // Department Field
                            TextFormField(
                              controller: _departmentController,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              enabled: _isEditing && !_isHR, // HR can't edit their department
                            ),
                            if (_employeeId.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              
                              // Employee ID Field (read-only)
                              TextFormField(
                                initialValue: _employeeId,
                                decoration: const InputDecoration(
                                  labelText: 'Employee ID',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge),
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
                              leading: const Icon(Icons.lock, color: Colors.blue),
                              title: const Text('Change Password'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: _changePassword,
                            ),
                            const Divider(),
                            
                            // Logout Button
                            ListTile(
                              leading: const Icon(Icons.exit_to_app, color: Colors.red),
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
                            const ListTile(
                              leading: Icon(Icons.info_outline, color: Colors.grey),
                              title: Text('DHL Leave Management System'),
                              subtitle: Text('Version 1.0.0'),
                            ),
                            const Divider(),
                            const ListTile(
                              leading: Icon(Icons.support_agent, color: Colors.grey),
                              title: Text('Need Help?'),
                              subtitle: Text('Contact HR Department'),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.policy, color: Colors.grey),
                              title: const Text('Privacy Policy'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Open privacy policy
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.description, color: Colors.grey),
                              title: const Text('Terms of Service'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Open terms of service
                              },
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
                  ],
                ),
              ),
            ),
    );
  }
}