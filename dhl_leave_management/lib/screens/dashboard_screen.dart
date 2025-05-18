import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:dhl_leave_management/screens/first_time_password_change_screen.dart';
import 'package:dhl_leave_management/screens/hr_notification_settings_screen.dart';
import 'package:dhl_leave_management/screens/leave_application_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userName = 'HR Admin';
  Map? _userDetails;
  
  // Initialize services
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();
  
  // For filtering employees
  final TextEditingController _employeeSearchController = TextEditingController();
  String _employeeSearchQuery = '';
  
  // For filtering leave applications
  String _leaveStatusFilter = 'All';
  final TextEditingController _leaveSearchController = TextEditingController();
  String _leaveSearchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    _employeeSearchController.addListener(() {
      setState(() {
        _employeeSearchQuery = _employeeSearchController.text.toLowerCase();
      });
    });
    
    _leaveSearchController.addListener(() {
      setState(() {
        _leaveSearchQuery = _leaveSearchController.text.toLowerCase();
      });
    });
  }
  
  @override
  void dispose() {
    _employeeSearchController.dispose();
    _leaveSearchController.dispose();
    super.dispose();
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
        title: Row(
          children: [
            Image.asset(
              'assets/DHL_Express_logo_rgb.png',
              height: 30,
            ),
            const SizedBox(width: 12),
            const Text('Leave Management System'),
          ],
        ),
        backgroundColor: const Color(0xFFD40511), // DHL Red
        elevation: 0,
        actions: [
          // AI Assistant button
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChatbotScreen(),
                ),
              );
            },
            tooltip: 'AI Assistant',
          ),
          // Import Excel button
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ImportScreen(),
                ),
              );
            },
            tooltip: 'Import Excel Data',
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: Drawer(
        elevation: 2,
        child: Container(
          color: Colors.white,
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
                    Image.asset(
                      'assets/DHL_Express_logo_rgb.png',
                      height: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      'HR Department',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.dashboard,
                  color: _selectedIndex == 0 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedIndex == 0 ? const Color(0xFFD40511) : Colors.black87,
                  ),
                ),
                selected: _selectedIndex == 0,
                selectedTileColor: Colors.red[50],
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.people,
                  color: _selectedIndex == 1 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Employees',
                  style: TextStyle(
                    fontWeight: _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedIndex == 1 ? const Color(0xFFD40511) : Colors.black87,
                  ),
                ),
                selected: _selectedIndex == 1,
                selectedTileColor: Colors.red[50],
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: _selectedIndex == 2 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Leave Applications',
                  style: TextStyle(
                    fontWeight: _selectedIndex == 2 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedIndex == 2 ? const Color(0xFFD40511) : Colors.black87,
                  ),
                ),
                selected: _selectedIndex == 2,
                selectedTileColor: Colors.red[50],
                onTap: () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: _selectedIndex == 3 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontWeight: _selectedIndex == 3 ? FontWeight.bold : FontWeight.normal,
                    color: _selectedIndex == 3 ? const Color(0xFFD40511) : Colors.black87,
                  ),
                ),
                selected: _selectedIndex == 3,
                selectedTileColor: Colors.red[50],
                onTap: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.exit_to_app,
                  color: Colors.red,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFD40511), // DHL Red
                ),
              )
            : _buildBody(),
      ),
      // Add FAB for quick actions depending on selected index
      floatingActionButton: _selectedIndex == 1 || _selectedIndex == 2
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedIndex == 1) {
                  _showAddEmployeeDialog();
                } else if (_selectedIndex == 2) {
                  // Navigate to leave application form
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LeaveApplicationForm(),
                    ),
                  );
                }
              },
              backgroundColor: const Color(0xFFD40511),
              child: Icon(_selectedIndex == 1 ? Icons.person_add : Icons.add),
            )
          : null,
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
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.dashboard,
                  color: Color(0xFFD40511),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                Text(
                  'Welcome back, ${_userName.split(' ')[0]}!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            totalLeaves.toString(),
                            const Color(0xFF1976D2),
                            Icons.list_alt,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            pendingLeaves.toString(),
                            const Color(0xFFFFA000),
                            Icons.pending_actions,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Approved',
                            approvedLeaves.toString(),
                            const Color(0xFF43A047),
                            Icons.check_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            'Rejected',
                            rejectedLeaves.toString(),
                            const Color(0xFFE53935),
                            Icons.cancel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Charts Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status distribution pie chart
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.pie_chart,
                                        color: Colors.grey[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Leave Status Distribution',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 200,
                                    child: PieChart(
                                      PieChartData(
                                        sections: [
                                          PieChartSectionData(
                                            value: pendingLeaves.toDouble(),
                                            title: '$pendingLeaves',
                                            color: const Color(0xFFFFA000),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: approvedLeaves.toDouble(),
                                            title: '$approvedLeaves',
                                            color: const Color(0xFF43A047),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: rejectedLeaves.toDouble(),
                                            title: '$rejectedLeaves',
                                            color: const Color(0xFFE53935),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                        centerSpaceColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  // Legend
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem('Pending', const Color(0xFFFFA000)),
                                      const SizedBox(width: 20),
                                      _buildLegendItem('Approved', const Color(0xFF43A047)),
                                      const SizedBox(width: 20),
                                      _buildLegendItem('Rejected', const Color(0xFFE53935)),
                                    ],
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
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.pie_chart,
                                        color: Colors.grey[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Leave Type Distribution',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 200,
                                    child: PieChart(
                                      PieChartData(
                                        sections: [
                                          PieChartSectionData(
                                            value: annualLeaves.toDouble(),
                                            title: '$annualLeaves',
                                            color: const Color(0xFF1976D2),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: medicalLeaves.toDouble(),
                                            title: '$medicalLeaves',
                                            color: const Color(0xFF9C27B0),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            value: emergencyLeaves.toDouble(),
                                            title: '$emergencyLeaves',
                                            color: const Color(0xFFFFB300),
                                            radius: 60,
                                            titleStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 40,
                                        centerSpaceColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  // Legend
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem('Annual', const Color(0xFF1976D2)),
                                      const SizedBox(width: 20),
                                      _buildLegendItem('Medical', const Color(0xFF9C27B0)),
                                      const SizedBox(width: 20),
                                      _buildLegendItem('Emergency', const Color(0xFFFFB300)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          // Recent leave applications
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history,
                            color: Colors.grey[700],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Recent Leave Applications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 2;
                          });
                        },
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: Color(0xFFD40511),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 4),
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
                        return ListView.separated(
                          itemCount: recentApplications.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final application = recentApplications[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFD40511).withOpacity(0.1),
                                child: Text(
                                  application.employeeName.isNotEmpty
                                    ? application.employeeName.substring(0, 1).toUpperCase()
                                    : '?',
                                  style: const TextStyle(
                                    color: Color(0xFFD40511),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                application.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${application.leaveType} - ${DateFormat('MMM d').format(application.startDate)} to ${DateFormat('MMM d').format(application.endDate)}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _getStatusChip(application.status),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
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

  // UPDATED EMPLOYEE LIST IMPLEMENTATION
  Widget _buildEmployeesList() {
    return Container(
      color: Colors.grey[100],
      child: StreamBuilder(
        stream: _firebaseService.getAllEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No employees found', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddEmployeeDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Employee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD40511),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Apply search filter if there's a query
          var employees = snapshot.data!.docs;
          if (_employeeSearchQuery.isNotEmpty) {
            employees = employees.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] as String? ?? '').toLowerCase();
              final id = (data['id'] as String? ?? '').toLowerCase();
              final department = (data['department'] as String? ?? '').toLowerCase();
              
              return name.contains(_employeeSearchQuery) || 
                     id.contains(_employeeSearchQuery) ||
                     department.contains(_employeeSearchQuery);
            }).toList();
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Color(0xFFD40511),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Employees',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddEmployeeDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Employee'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD40511),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _employeeSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search employees...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _employeeSearchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _employeeSearchController.clear();
                          },
                        )
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
              ),
              
              // Employee count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Showing ${employees.length} employees',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              
              // Employee list
              Expanded(
                child: employees.isEmpty
                    ? Center(
                        child: Text(
                          'No employees match your search',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      )
                    : ListView.builder(
                        key: const PageStorageKey<String>('employeeListView'),
                        padding: const EdgeInsets.all(16),
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final doc = employees[index];
                          final employee = doc.data() as Map<String, dynamic>;
                          final employeeId = employee['id'] as String? ?? '';
                          final employeeName = employee['name'] as String? ?? 'Unknown';
                          final department = employee['department'] as String? ?? 'Department not assigned';
                          
                      return Card(
                            key: ValueKey<String>(employeeId),
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Employee info
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFD40511),
                                    child: Text(
                                      employeeName.isNotEmpty ? employeeName.substring(0, 1).toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    employeeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'ID: $employeeId',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        department,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      _showEmployeeActions(employeeId, employeeName);
                                    },
                                  ),
                                ),
                                
                                // Quick action buttons
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => LeaveApplicationForm(
                                                  employeeId: employeeId,
                                                  employeeName: employeeName,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.add_circle_outline, size: 18),
                                          label: const Text('Apply Leave'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFD40511),
                                            side: const BorderSide(color: Color(0xFFD40511)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            _showEmployeeLeaveHistory(employeeId, employeeName);
                                          },
                                          icon: const Icon(Icons.history, size: 18),
                                          label: const Text('Leave History'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                            side: const BorderSide(color: Colors.blue),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildLeaveApplicationsList() {
    return Container(
      color: Colors.grey[100],
      child: StreamBuilder<List<LeaveApplication>>(
        stream: _firebaseService.getAllLeaveApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No leave applications found', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LeaveApplicationForm(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Leave Application'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD40511),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Apply filters
          var applications = snapshot.data!;
          
          // Filter by status
          if (_leaveStatusFilter != 'All') {
            applications = applications.where((app) => 
              app.status.toLowerCase() == _leaveStatusFilter.toLowerCase()
            ).toList();
          }
          
          // Filter by search query
          if (_leaveSearchQuery.isNotEmpty) {
            applications = applications.where((app) {
              return app.employeeName.toLowerCase().contains(_leaveSearchQuery) ||
                     app.employeeId.toLowerCase().contains(_leaveSearchQuery) ||
                     app.leaveType.toLowerCase().contains(_leaveSearchQuery);
            }).toList();
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xFFD40511),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Leave Applications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<String>(
                        value: _leaveStatusFilter,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD40511)),
                        items: ['All', 'Pending', 'Approved', 'Rejected']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _leaveStatusFilter = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _leaveSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search applications...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _leaveSearchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _leaveSearchController.clear();
                                },
                              )
                            : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Date filter
                        },
                        icon: const Icon(Icons.date_range, color: Color(0xFFD40511)),
                        tooltip: 'Filter by Date',
                      ),
                    ),
                  ],
                ),
              ),
              
              // Applications count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Showing ${applications.length} applications',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              
              // Applications list
              Expanded(
                child: applications.isEmpty
                    ? Center(
                        child: Text(
                          'No leave applications match your criteria',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      )
                    : ListView.builder(
                        key: const PageStorageKey<String>('leaveApplicationsListView'),
                        padding: const EdgeInsets.all(16),
                        itemCount: applications.length,
                        itemBuilder: (context, index) {
                          final application = applications[index];
                          return Card(
                            key: ValueKey<String>(application.id),
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFFD40511).withOpacity(0.1),
                                            child: Text(
                                              application.employeeName.isNotEmpty 
                                                ? application.employeeName.substring(0, 1).toUpperCase()
                                                : '?',
                                              style: const TextStyle(
                                                color: Color(0xFFD40511),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                application.employeeName,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF333333),
                                                ),
                                              ),
                                              Text(
                                                'Employee ID: ${application.employeeId}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      _getStatusChip(application.status),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Leave Type:',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                application.leaveType,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF333333),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.date_range,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Duration:',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${DateFormat('MMM d, yyyy').format(application.startDate)} to ${DateFormat('MMM d, yyyy').format(application.endDate)} (${application.calculateDuration()} days)',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF333333),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => LeaveDetailScreen(leaveId: application.id),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.visibility, size: 16),
                                        label: const Text('View Details'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                          side: const BorderSide(color: Colors.blue),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (application.status == 'Pending') ...[
                                            TextButton(
                                              onPressed: () {
                                                _showRejectDialog(application.id);
                                              },
                                              child: const Text('Reject'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
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
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                            ),
                                          ],
                                          if (application.status != 'Pending') ...[
                                            TextButton(
                                              onPressed: () {
                                                _updateLeaveStatus(application.id, 'Pending');
                                              },
                                              child: const Text('Reset to Pending'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.grey[700],
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
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
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildSettings() {
    return Container(
      color: Colors.grey[100],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Color(0xFFD40511),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          // Settings sections
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'User Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF1976D2)),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock, color: Color(0xFF43A047)),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FirstTimePasswordChangeScreen(
                          email: FirebaseAuth.instance.currentUser?.email ?? '',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'System Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Color(0xFF9C27B0)),
                  title: const Text('Import Excel Data'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ImportScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent, color: Color(0xFFFFA000)),
                  title: const Text('AI Assistant'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChatbotScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications, color: Color(0xFF1976D2)),
                  title: const Text('Notification Settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HRNotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(
                Icons.exit_to_app,
                color: Colors.red,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/DHL_Express_logo_rgb.png',
                  height: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  'DHL Leave Management System v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
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
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
  
  Widget _getStatusChip(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Pending':
        color = const Color(0xFFFFA000);
        icon = Icons.pending_actions;
        break;
      case 'Approved':
        color = const Color(0xFF43A047);
        icon = Icons.check_circle;
        break;
      case 'Rejected':
        color = const Color(0xFFE53935);
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  // DIALOG METHODS FOR EMPLOYEE AND LEAVE MANAGEMENT
  
  // Add Employee Dialog
  void _showAddEmployeeDialog() {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final departmentController = TextEditingController();
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || 
                  idController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Employee ID are required')),
                );
                return;
              }
              
              // Add the employee to Firestore
              try {
                await _firebaseService.addEmployee(
                  id: idController.text.trim(),
                  name: nameController.text.trim(),
                  department: departmentController.text.trim(),
                  email: emailController.text.trim().isNotEmpty ? emailController.text.trim() : null,
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Employee added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding employee: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD40511),
            ),
            child: const Text('Add Employee'),
          ),
        ],
      ),
    );
  }
  
  // Show Employee Actions Bottom Sheet
  void _showEmployeeActions(String employeeId, String employeeName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFD40511).withOpacity(0.1),
                  child: Text(
                    employeeName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Color(0xFFD40511)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  employeeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Color(0xFFD40511)),
            title: const Text('Apply for Leave'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LeaveApplicationForm(
                    employeeId: employeeId,
                    employeeName: employeeName,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: const Text('View Leave History'),
            onTap: () {
              Navigator.pop(context);
              _showEmployeeLeaveHistory(employeeId, employeeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.orange),
            title: const Text('Edit Employee Details'),
            onTap: () {
              Navigator.pop(context);
              _showEditEmployeeDialog(employeeId, employeeName);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Employee'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteEmployeeConfirmation(employeeId, employeeName);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // Show Employee Leave History
void _showEmployeeLeaveHistory(String employeeId, String employeeName) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text('$employeeName - Leave History'),
          backgroundColor: const Color(0xFFD40511),
        ),
        body: StreamBuilder<List<LeaveApplication>>(
          stream: _firebaseService.getEmployeeLeaveApplications(employeeId),
          builder: (context, snapshot) {
            // Error handling with retry option
            if (snapshot.hasError) {
              print("StreamBuilder error: ${snapshot.error}");
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading leave history',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEmployeeLeaveHistory(employeeId, employeeName);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD40511),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // Loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFD40511)),
                    SizedBox(height: 24),
                    Text("Loading leave history...", 
                      style: TextStyle(color: Colors.grey)
                    ),
                  ],
                ),
              );
            }
            
            // Empty state with better visuals
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 24),
                    const Text(
                      'No leave applications found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This employee has no leave history yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LeaveApplicationForm(
                              employeeId: employeeId,
                              employeeName: employeeName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Leave Application'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD40511),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            // Group applications by year for better organization
            final applications = snapshot.data!;
            final applicationsByYear = <int, List<LeaveApplication>>{};
            
            // Group applications by year
            for (final application in applications) {
              final year = application.startDate.year;
              if (!applicationsByYear.containsKey(year)) {
                applicationsByYear[year] = [];
              }
              applicationsByYear[year]!.add(application);
            }
            
            // Sort years in descending order (newest first)
            final years = applicationsByYear.keys.toList()..sort((a, b) => b.compareTo(a));
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: years.length,
              itemBuilder: (context, yearIndex) {
                final year = years[yearIndex];
                final yearApplications = applicationsByYear[year]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year header
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16, left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD40511).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$year',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD40511),
                        ),
                      ),
                    ),
                    // Leave applications for this year
                    ...yearApplications.map((leave) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => LeaveDetailScreen(leaveId: leave.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          leave.leaveType.toLowerCase().contains('annual') 
                                              ? Icons.beach_access
                                              : leave.leaveType.toLowerCase().contains('medical')
                                                  ? Icons.medical_services
                                                  : Icons.event,
                                          color: const Color(0xFFD40511),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          leave.leaveType,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    _getStatusChip(leave.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${DateFormat('MMM d').format(leave.startDate)} to ${DateFormat('MMM d').format(leave.endDate)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${leave.calculateDuration()} days)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Reason: ${leave.reason}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LeaveApplicationForm(
                  employeeId: employeeId,
                  employeeName: employeeName,
                ),
              ),
            );
          },
          backgroundColor: const Color(0xFFD40511),
          child: const Icon(Icons.add),
        ),
      ),
    ),
  );
}
  
  // Show Edit Employee Dialog
  void _showEditEmployeeDialog(String employeeId, String employeeName) {
    _firebaseService.getEmployeeById(employeeId).then((employeeData) {
      if (employeeData != null && mounted) {
        final nameController = TextEditingController(text: employeeData['name'] ?? '');
        final departmentController = TextEditingController(text: employeeData['department'] ?? '');
        final emailController = TextEditingController(text: employeeData['email'] ?? '');

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Edit Employee'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: employeeId),
                    decoration: const InputDecoration(
                      labelText: 'Employee ID (cannot be changed)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty')),
                    );
                    return;
                  }
                  
                  try {
                    await _firebaseService.updateEmployee(
                      id: employeeId,
                      name: nameController.text.trim(),
                      department: departmentController.text.trim(),
                      email: emailController.text.trim(),
                    );
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Employee updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating employee: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD40511),
                ),
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    });
  }
  
  // Show Delete Employee Confirmation Dialog
  void _showDeleteEmployeeConfirmation(String employeeId, String employeeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete $employeeName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firebaseService.deleteEmployee(employeeId);
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Employee deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting employee: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  // Show Reject Dialog for Leave Application
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
                  _updateLeaveStatus(
                    leaveId,
                    'Rejected',
                    rejectReason: reasonController.text.trim(),
                  );
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
  
  // Update Leave Status
  Future<void> _updateLeaveStatus(
    String leaveId,
    String newStatus, {
    String? rejectReason,
  }) async {
    try {
      await _firebaseService.updateLeaveStatus(
        leaveId,
        newStatus,
        rejectReason: rejectReason,
      );
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
              