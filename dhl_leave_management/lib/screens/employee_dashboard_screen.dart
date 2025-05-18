import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'package:dhl_leave_management/services/auth_service.dart';
import 'package:dhl_leave_management/services/firebase_service.dart';
import 'package:dhl_leave_management/screens/login_screen.dart';
import 'package:dhl_leave_management/screens/leave_application_form.dart';
import 'package:dhl_leave_management/screens/leave_detail_screen.dart';
import 'package:dhl_leave_management/screens/profile_screen.dart';
import 'package:dhl_leave_management/screens/chatbot_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  // Initialize services
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  
  String _employeeName = '';
  String _employeeId = '';
  bool _isLoading = true;
  int _pendingLeaves = 0;
  int _approvedLeaves = 0;
  int _rejectedLeaves = 0;
  Map<String, dynamic>? _userDetails;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    try {
      // Get current user details from auth service
      final userDetails = await _authService.getCurrentUserDetails();
      
      if (userDetails == null) {
        // Navigate to login if no user is found
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }
      
      // Get employee ID
      final String? employeeId = userDetails['employeeId'];
      
      // Set user and employee info
      setState(() {
        _employeeName = userDetails['name'] ?? 'Employee';
        _userDetails = userDetails;
      });
      
      if (employeeId != null) {
        // Get employee leave statistics
        final leaveStats = await _firebaseService.getEmployeeLeaveStatistics(employeeId);
        
        setState(() {
          _employeeId = employeeId;
          _pendingLeaves = leaveStats['status']?['pending'] ?? 0;
          _approvedLeaves = leaveStats['status']?['approved'] ?? 0;
          _rejectedLeaves = leaveStats['status']?['rejected'] ?? 0;
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading employee data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
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
  
  Future<void> _cancelLeaveApplication(String leaveId) async {
    // Show confirmation dialog
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Leave Application'),
          content: const Text('Are you sure you want to cancel this leave application? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (!confirm) return;
    
    // Delete the leave application
    try {
      await _firebaseService.deleteLeaveApplication(leaveId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling leave application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave Dashboard'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
        actions: [
          // AI Assistant button
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
            tooltip: 'AI Assistant',
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD40511), // DHL Red
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEmployeeData,
              color: const Color(0xFFD40511),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome card
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFD40511),
                                  radius: 30,
                                  child: Text(
                                    _employeeName.isNotEmpty
                                        ? _employeeName.substring(0, 1).toUpperCase()
                                        : 'E',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, $_employeeName',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_employeeId.isNotEmpty)
                                        Text(
                                          'Employee ID: $_employeeId',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Today: ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_userDetails?['department'] != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.business, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Department: ${_userDetails!['department']}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Leave statistics
                    const Text(
                      'Leave Applications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            _pendingLeaves.toString(),
                            Colors.orange,
                            Icons.pending_actions,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Approved',
                            _approvedLeaves.toString(),
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Rejected',
                            _rejectedLeaves.toString(),
                            Colors.red,
                            Icons.cancel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Leave Application Button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to leave application form
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LeaveApplicationForm(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Apply for Leave'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD40511), // DHL Red
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // My Leave Applications
                    const Text(
                      'My Leave Applications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Leave applications list
                    _employeeId.isEmpty
                        ? const Center(
                            child: Text(
                              'No employee ID found. Please contact HR.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : StreamBuilder<List<LeaveApplication>>(
                            stream: _firebaseService.getEmployeeLeaveApplications(_employeeId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.event_busy,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No leave applications found',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => LeaveApplicationForm(),
                                              ),
                                            );
                                          },
                                          child: const Text('Apply for your first leave'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              
                              final leaves = snapshot.data!;
                              
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: leaves.length,
                                itemBuilder: (context, index) {
                                  final leave = leaves[index];
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: InkWell(
                                      onTap: () {
                                        // Navigate to leave detail screen
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => LeaveDetailScreen(leaveId: leave.id),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  leave.leaveType,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                _buildStatusChip(leave.status),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                const Icon(Icons.date_range, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${DateFormat('MMM d, yyyy').format(leave.startDate)} - ${DateFormat('MMM d, yyyy').format(leave.endDate)} (${leave.calculateDuration()} days)',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Applied on ${DateFormat('MMM d, yyyy').format(leave.createdAt)}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (leave.status == 'Pending') ...[
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () => _cancelLeaveApplication(leave.id),
                                                    icon: const Icon(Icons.cancel),
                                                    label: const Text('Cancel Application'),
                                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (leave.status == 'Rejected' && leave.rejectReason != null) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.info_outline, color: Colors.red),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Reason: ${leave.rejectReason}',
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to leave application form
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LeaveApplicationForm(),
            ),
          );
        },
        backgroundColor: const Color(0xFFD40511), // DHL Red
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case 'Pending':
        color = Colors.orange;
        icon = Icons.pending_actions;
        break;
      case 'Approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    
    return Chip(
      label: Text(status),
      avatar: Icon(icon, color: Colors.white, size: 16),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
}