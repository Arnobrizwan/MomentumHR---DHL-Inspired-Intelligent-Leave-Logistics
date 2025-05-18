import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'package:dhl_leave_management/services/auth_service.dart';
import 'package:dhl_leave_management/services/firebase_service.dart';
import 'package:dhl_leave_management/screens/profile_screen.dart';
import 'package:dhl_leave_management/screens/import_screen.dart';
import 'package:dhl_leave_management/screens/leave_detail_screen.dart';
import 'package:dhl_leave_management/screens/chatbot_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userName = 'HR Admin';
  Map<String, dynamic>? _userDetails;
  
  // Initialize services
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      final userDetails = await _authService.getCurrentUserDetails();
      if (userDetails != null) {
        setState(() {
          _userName = userDetails['name'] ?? 'HR Admin';
          _userDetails = userDetails;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user data: $e'),
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
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
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
        title: const Text('DHL Leave Management'),
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
          // Import Excel button
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
            tooltip: 'Import Excel Data',
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
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFD40511), // DHL Red
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/a/ac/DHL_Logo.svg',
                    height: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const Text(
                    'HR Department',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Employees'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Leave Applications'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD40511), // DHL Red
              ),
            )
          : _buildBody(),
    );
  }
  
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildEmployeesList();
      case 2:
        return _buildLeaveApplicationsList();
      case 3:
        return _buildSettings();
      default:
        return _buildDashboard();
    }
  }
  
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistics Cards
          FutureBuilder<Map<String, dynamic>>(
            future: _firebaseService.getLeaveStatistics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                return const Center(child: Text('No leave statistics available'));
              }
              
              final stats = snapshot.data!;
              final totalLeaves = stats['total'] ?? 0;
              final pendingLeaves = stats['status']?['pending'] ?? 0;
              final approvedLeaves = stats['status']?['approved'] ?? 0;
              final rejectedLeaves = stats['status']?['rejected'] ?? 0;
              final annualLeaves = stats['type']?['annual'] ?? 0;
              final medicalLeaves = stats['type']?['medical'] ?? 0;
              final emergencyLeaves = stats['type']?['emergency'] ?? 0;
              
              return Column(
                children: [
                  // Status Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          totalLeaves.toString(),
                          Colors.blue,
                          Icons.list_alt,
                        ),
                      ),
                      Expanded(
                        child: _buildStatCard(
                          'Pending',
                          pendingLeaves.toString(),
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                      ),
                      Expanded(
                        child: _buildStatCard(
                          'Approved',
                          approvedLeaves.toString(),
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      Expanded(
                        child: _buildStatCard(
                          'Rejected',
                          rejectedLeaves.toString(),
                          Colors.red,
                          Icons.cancel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Charts
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status distribution pie chart
                      Expanded(
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Leave Status Distribution',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: [
                                        PieChartSectionData(
                                          value: pendingLeaves.toDouble(),
                                          title: 'Pending',
                                          color: Colors.orange,
                                          radius: 60,
                                        ),
                                        PieChartSectionData(
                                          value: approvedLeaves.toDouble(),
                                          title: 'Approved',
                                          color: Colors.green,
                                          radius: 60,
                                        ),
                                        PieChartSectionData(
                                          value: rejectedLeaves.toDouble(),
                                          title: 'Rejected',
                                          color: Colors.red,
                                          radius: 60,
                                        ),
                                      ],
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Leave type distribution pie chart
                      Expanded(
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Leave Type Distribution',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: [
                                        PieChartSectionData(
                                          value: annualLeaves.toDouble(),
                                          title: 'Annual',
                                          color: Colors.blue,
                                          radius: 60,
                                        ),
                                        PieChartSectionData(
                                          value: medicalLeaves.toDouble(),
                                          title: 'Medical',
                                          color: Colors.purple,
                                          radius: 60,
                                        ),
                                        PieChartSectionData(
                                          value: emergencyLeaves.toDouble(),
                                          title: 'Emergency',
                                          color: Colors.amber,
                                          radius: 60,
                                        ),
                                      ],
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
                  
          // Recent leave applications
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Leave Applications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: StreamBuilder<List<LeaveApplication>>(
                      stream: _firebaseService.getAllLeaveApplications(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No leave applications found'));
                        }
                        
                        final applications = snapshot.data!;
                        final recentApplications = applications.length > 5 
                          ? applications.sublist(0, 5) 
                          : applications;
                          
                        return ListView.builder(
                          itemCount: recentApplications.length,
                          itemBuilder: (context, index) {
                            final application = recentApplications[index];
                            
                            return ListTile(
                              title: Text(application.employeeName),
                              subtitle: Text(
                                '${application.leaveType} - ${DateFormat('MMM d').format(application.startDate)} to ${DateFormat('MMM d').format(application.endDate)}'
                              ),
                              trailing: _getStatusChip(application.status),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => LeaveDetailScreen(leaveId: application.id),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmployeesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getAllEmployees(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No employees found'));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final employee = snapshot.data!.docs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFD40511),
                  child: Text(
                    employee['name'].toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(employee['name']),
                subtitle: Text('ID: ${employee['id']} - ${employee['department'] ?? 'N/A'}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to employee details or create leave for employee
                  Navigator.pushNamed(
                    context,
                    '/leave/apply',
                    arguments: {
                      'employeeId': employee['id'],
                      'employeeName': employee['name'],
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildLeaveApplicationsList() {
    return StreamBuilder<List<LeaveApplication>>(
      stream: _firebaseService.getAllLeaveApplications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No leave applications found'));
        }
        
        final applications = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          application.employeeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _getStatusChip(application.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Employee ID: ${application.employeeId}'),
                    const SizedBox(height: 4),
                    Text('Leave Type: ${application.leaveType}'),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${DateFormat('MMM d, yyyy').format(application.startDate)} to ${DateFormat('MMM d, yyyy').format(application.endDate)} (${application.calculateDuration()} days)',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LeaveDetailScreen(leaveId: application.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Details'),
                          style: TextButton.styleFrom(foregroundColor: Colors.blue),
                        ),
                        Row(
                          children: [
                            if (application.status == 'Pending') ...[
                              TextButton(
                                onPressed: () {
                                  _showRejectDialog(application.id);
                                },
                                child: const Text('Reject'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _updateLeaveStatus(application.id, 'Approved');
                                },
                                child: const Text('Approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                            if (application.status != 'Pending') ...[
                              TextButton(
                                onPressed: () {
                                  _updateLeaveStatus(application.id, 'Pending');
                                },
                                child: const Text('Reset to Pending'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Excel Data'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('AI Assistant'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.red.shade50,
          child: ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ),
      ],
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
  
  Widget _getStatusChip(String status) {
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
  
  Future<void> _showRejectDialog(String leaveId) async {
    final TextEditingController reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for Rejection'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason for rejection',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _updateLeaveStatus(leaveId, 'Rejected', rejectReason: reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _updateLeaveStatus(String leaveId, String newStatus, {String? rejectReason}) async {
    try {
      await _firebaseService.updateLeaveStatus(leaveId, newStatus, rejectReason: rejectReason);
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave application $newStatus successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}