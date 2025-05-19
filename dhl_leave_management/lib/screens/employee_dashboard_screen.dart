import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'package:dhl_leave_management/services/auth_service.dart';
import 'package:dhl_leave_management/services/firebase_service.dart';
import 'package:dhl_leave_management/screens/profile_screen.dart';
import 'package:dhl_leave_management/screens/leave_detail_screen.dart';
import 'package:dhl_leave_management/screens/chatbot_screen.dart';
import 'package:dhl_leave_management/screens/leave_application_form.dart';
import 'package:dhl_leave_management/screens/first_time_password_change_screen.dart';
import 'package:dhl_leave_management/screens/employee_notification_settings_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});
  
  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userName = 'Employee';
  String _employeeId = '';
  String _userEmail = '';
  String _department = '';
  Map<String, dynamic>? _userDetails;
  
  // Status filter for leave applications
  String _leaveStatusFilter = 'All';
  String _leaveTypeFilter = 'All';
  
  // Search filter for leave applications
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  
  // Date range filter for leave applications
  DateTimeRange? _selectedDateRange;
  
  // Initialize services
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

Future<Map<String, dynamic>?> _autoLinkUserToEmployee(User currentUser) async {
  try {
    final q = await FirebaseFirestore.instance
      .collection('employees')
      .where('email', isEqualTo: currentUser.email)
      .limit(1)
      .get();

    if (q.docs.isEmpty) return null;

    final emp = q.docs.first.data();
    final empId = emp['id'] as String?;
    if (empId == null || empId.isEmpty) return null;

    // Link in /users
    await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .set({
        'email': currentUser.email,
        'name': emp['name'] ?? currentUser.displayName,
        'userType': 'EMPLOYEE',
        'employeeId': empId,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

    // Back-link in /employees
    await FirebaseFirestore.instance
      .collection('employees')
      .doc(empId)
      .update({
        'userId': currentUser.uid,
        'updatedAt': Timestamp.now(),
      });

    return {
      ...emp,
      'id': empId,
      'name': emp['name'] ?? currentUser.displayName,
      'employeeId': empId,
    };
  } catch (e) {
    print('auto-link error: $e');
    return null;
  }
}
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
  
  Future<void> _loadUserData() async {
  setState(() => _isLoading = true);

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    // not authenticated → kick back to login
    await _authService.logout();
    return;
  }

  final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .get();

  Map<String, dynamic>? data;

  if (userDoc.exists && (userDoc.data()?['employeeId'] as String?)?.isNotEmpty == true) {
    data = userDoc.data();
  } else {
    // try to auto-link by email
    data = await _autoLinkUserToEmployee(currentUser);
    if (data == null) {
      // fallback: create minimal user and ask HR
      await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .set({
          'email': currentUser.email,
          'name': currentUser.displayName ?? 'Employee',
          'userType': 'EMPLOYEE',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account not linked—please contact HR'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      data = {
        'name': currentUser.displayName ?? 'Employee',
        'employeeId': '',
        'department': '',
      };
    }
  }

  // Now we have at least `name`, `employeeId`, `department`
  setState(() {
    _userName    = data!['name']       as String;
    _employeeId  = data['employeeId']  as String;
    _department  = data['department'] ?? '';
    _userEmail   = currentUser.email   ?? '';
    _userDetails = data;
    _isLoading   = false;
  });
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
  
  Future<void> _selectDateRange() async {
    final initialDateRange = _selectedDateRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD40511),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
    }
  }
  
  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
  }
  
  void _applyForLeave() {
    // Navigate to the leave application form
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaveApplicationForm(
          employeeId: _employeeId,
          employeeName: _userName,
        ),
      ),
    ).then((_) {
      // When returning from the leave application form, refresh the view
      setState(() {
        _selectedIndex = 1; // Switch to My Applications tab
      });
      
      // Show a success message (assuming the form submission was successful)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave application submitted successfully for HR approval'),
          backgroundColor: Colors.green,
        ),
      );
    });
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
            const Text('Employee Leave Portal'),
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
          // Notifications button
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Show notifications (you could implement a notification screen here)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications feature coming soon'),
                ),
              );
            },
            tooltip: 'Notifications',
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
                    Text(
                      'Employee ID: $_employeeId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (_department.isNotEmpty) Text(
                      'Department: $_department',
                      style: const TextStyle(
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
                  Icons.calendar_today,
                  color: _selectedIndex == 1 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'My Applications',
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
                  Icons.analytics,
                  color: _selectedIndex == 2 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Leave Analysis',
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
                  Icons.support_agent,
                  color: Colors.blue,
                ),
                title: const Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.blue,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChatbotScreen(),
                    ),
                  );
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
            : IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildDashboard(),
                  _buildMyApplications(),
                  _buildLeaveAnalysis(),
                  _buildSettings(),
                ],
              ),
      ),
      // Add FAB for quick actions - apply for leave
      floatingActionButton: (_selectedIndex != 3)
          ? FloatingActionButton.extended(
              onPressed: _applyForLeave,
              backgroundColor: const Color(0xFFD40511),
              icon: const Icon(Icons.add),
              label: const Text('Apply for Leave'),
            )
          : null,
    );
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
                  'My Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                Text(
                  'Hello, ${_userName.split(' ')[0]}!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Welcome card with quick actions
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.add_circle,
                        label: 'Apply\nLeave',
                        color: const Color(0xFFD40511),
                        onTap: _applyForLeave,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.history,
                        label: 'Leave\nHistory',
                        color: Colors.blue,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 1; // Switch to My Applications tab
                          });
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.analytics,
                        label: 'Leave\nAnalysis',
                        color: Colors.purple,
                        onTap: () {
                          setState(() {
                            _selectedIndex = 2; // Switch to Leave Analysis tab
                          });
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.support_agent,
                        label: 'AI\nAssistant',
                        color: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChatbotScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Personal Leave Stats
          FutureBuilder<Map<String, dynamic>>(
            future: _firebaseService.getEmployeeLeaveStatistics(_employeeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No leave statistics available yet. Apply for leave to get started!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }
              
              final stats = snapshot.data!;
              final totalLeaves = stats['total'] ?? 0;
              final pendingLeaves = stats['status']?['pending'] ?? 0;
              final approvedLeaves = stats['status']?['approved'] ?? 0;
              final rejectedLeaves = stats['status']?['rejected'] ?? 0;
              final annualLeaves = stats['type']?['annual'] ?? 0;
              final medicalLeaves = stats['type']?['medical'] ?? 0;
              final emergencyLeaves = stats['type']?['emergency'] ?? 0;
              
              // Leave balance breakdown
              final annualBalance = stats['balance']?['annual'] ?? 21; // Default values if not provided
              final medicalBalance = stats['balance']?['medical'] ?? 14;
              final emergencyBalance = stats['balance']?['emergency'] ?? 5;
              
              return Column(
                children: [
                  // Leave Balance Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Leave Balance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildLeaveBalanceItem(
                                'Annual Leave',
                                annualBalance.toString(),
                                Colors.blue,
                                Icons.beach_access,
                              ),
                              const SizedBox(width: 8),
                              _buildLeaveBalanceItem(
                                'Medical Leave',
                                medicalBalance.toString(),
                                Colors.purple,
                                Icons.medical_services,
                              ),
                              const SizedBox(width: 8),
                              _buildLeaveBalanceItem(
                                'Emergency Leave',
                                emergencyBalance.toString(),
                                Colors.orange,
                                Icons.warning_amber_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('Learn about leave policies'),
                              onPressed: () {
                                _showLeavePolicy();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Status Statistics
                  Row(
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
                  const SizedBox(height: 24),
                  
                  // Charts Section - Leave Status Distribution
                  if (totalLeaves > 0) ... [
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
                              children: [
                                Icon(Icons.pie_chart,
                                  color: Colors.grey[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'My Leave Status Distribution',
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
                                    if (pendingLeaves > 0)
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
                                    if (approvedLeaves > 0)
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
                                    if (rejectedLeaves > 0)
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
                    const SizedBox(height: 24),
                  
                    // Charts Section - Leave Type Distribution
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
                              children: [
                                Icon(Icons.pie_chart,
                                  color: Colors.grey[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'My Leave Type Distribution',
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
                                    if (annualLeaves > 0)
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
                                    if (medicalLeaves > 0)
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
                                    if (emergencyLeaves > 0)
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
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          
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
                            'My Recent Applications',
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
                            _selectedIndex = 1;
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
                      stream: _firebaseService.getEmployeeLeaveApplications(_employeeId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No leave applications yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Apply for leave using the + button',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          );
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
                                backgroundColor: _getLeaveTypeColor(application.leaveType).withOpacity(0.1),
                                child: Icon(
                                  _getLeaveTypeIcon(application.leaveType),
                                  color: _getLeaveTypeColor(application.leaveType),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                application.leaveType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${DateFormat('MMM d').format(application.startDate)} to ${DateFormat('MMM d').format(application.endDate)} (${application.calculateDuration()} days)',
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildMyApplications() {
    return Container(
      color: Colors.grey[100],
      child: Column(
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
                  'My Leave Applications',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          
          // Filter options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Status filter
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: DropdownButton<String>(
                      value: _leaveStatusFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('Filter by status'),
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
                ),
                const SizedBox(width: 8),
                
                // Type filter
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: DropdownButton<String>(
                      value: _leaveTypeFilter,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('Filter by type'),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD40511)),
                      items: ['All', 'Annual Leave', 'Medical Leave', 'Emergency Leave']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _leaveTypeFilter = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Date range and search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Date range button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 20, color: Color(0xFFD40511)),
                          const SizedBox(width: 4),
                          Text(
                            _selectedDateRange != null
                                ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                                : 'Date Range',
                            style: TextStyle(
                              color: _selectedDateRange != null ? Colors.black : Colors.grey[600],
                            ),
                          ),
                          if (_selectedDateRange != null) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _clearDateRange,
                              borderRadius: BorderRadius.circular(12),
                              child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Search box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search leave applications...',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Leave applications list
          Expanded(
            child: StreamBuilder<List<LeaveApplication>>(
              stream: _firebaseService.getEmployeeLeaveApplications(_employeeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No leave applications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Apply for leave using the + button',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _applyForLeave,
                          icon: const Icon(Icons.add),
                          label: const Text('Apply for Leave'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD40511),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                
                // Filter by type
                if (_leaveTypeFilter != 'All') {
                  applications = applications.where((app) => 
                    app.leaveType.toLowerCase().contains(_leaveTypeFilter.toLowerCase())
                  ).toList();
                }
                
                // Filter by date range
                if (_selectedDateRange != null) {
                  applications = applications.where((app) {
                    // Include applications that overlap with the selected date range
                    final appStart = app.startDate;
                    final appEnd = app.endDate;
                    final rangeStart = _selectedDateRange!.start;
                    final rangeEnd = _selectedDateRange!.end;
                    
                    // Check for overlap
                    return (appStart.isBefore(rangeEnd) || appStart.isAtSameMomentAs(rangeEnd)) &&
                           (appEnd.isAfter(rangeStart) || appEnd.isAtSameMomentAs(rangeStart));
                  }).toList();
                }
                
                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  applications = applications.where((app) {
                    return app.leaveType.toLowerCase().contains(_searchQuery) ||
                           app.reason?.toLowerCase().contains(_searchQuery) == true ||
                           app.status.toLowerCase().contains(_searchQuery) ||
                           DateFormat('MMM d, yyyy').format(app.startDate).toLowerCase().contains(_searchQuery) ||
                           DateFormat('MMM d, yyyy').format(app.endDate).toLowerCase().contains(_searchQuery);
                  }).toList();
                }
                
                if (applications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No applications match your filters',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _leaveStatusFilter = 'All';
                              _leaveTypeFilter = 'All';
                              _selectedDateRange = null;
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  );
                }
                
                // Group applications by year
                final applicationsByYear = <int, List<LeaveApplication>>{};
                for (final app in applications) {
                  final year = app.startDate.year;
                  if (!applicationsByYear.containsKey(year)) {
                    applicationsByYear[year] = [];
                  }
                  applicationsByYear[year]!.add(app);
                }
                
                // Sort years in descending order
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
                                          Icon(
                                            _getLeaveTypeIcon(leave.leaveType),
                                            color: _getLeaveTypeColor(leave.leaveType),
                                            size: 20,
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
                                              flex: 1,
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
                                                '${DateFormat('MMM d, yyyy').format(leave.startDate)} to ${DateFormat('MMM d, yyyy').format(leave.endDate)} (${leave.calculateDuration()} days)',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.description,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Reason:',
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
                                                  leave.reason ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (leave.status == 'Rejected' && leave.rejectReason != null && leave.rejectReason!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 16,
                                                      color: Colors.red[400],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Rejection Reason:',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.red[400],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  leave.rejectReason ?? '',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.red[800],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => LeaveDetailScreen(leaveId: leave.id),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.visibility, size: 16),
                                        label: const Text('View Details'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                      if (leave.status == 'Pending') ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () {
                                            _showCancelLeaveDialog(leave.id);
                                          },
                                          icon: const Icon(Icons.cancel, size: 16),
                                          label: const Text('Cancel Application'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildLeaveAnalysis() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firebaseService.getEmployeeLeaveStatistics(_employeeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
            child: Text('Failed to load leave statistics'),
          );
        }
        
        final stats = snapshot.data!;
        final totalLeaves = stats['total'] ?? 0;
        
        if (totalLeaves == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.analytics,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No leave data available yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Apply for leave to see analytics',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _applyForLeave,
                  icon: const Icon(Icons.add),
                  label: const Text('Apply for Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD40511),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
        
        final pendingLeaves = stats['status']?['pending'] ?? 0;
        final approvedLeaves = stats['status']?['approved'] ?? 0;
        final rejectedLeaves = stats['status']?['rejected'] ?? 0;
        final annualLeaves = stats['type']?['annual'] ?? 0;
        final medicalLeaves = stats['type']?['medical'] ?? 0;
        final emergencyLeaves = stats['type']?['emergency'] ?? 0;
        
        // Leave balance
        final annualBalance = stats['balance']?['annual'] ?? 21; // Default annual leave
        final medicalBalance = stats['balance']?['medical'] ?? 14; // Default medical leave
        final emergencyBalance = stats['balance']?['emergency'] ?? 5; // Default emergency leave
        
        // Calculate used leaves
        final annualUsed = annualBalance > annualLeaves ? annualLeaves : annualBalance;
        final medicalUsed = medicalBalance > medicalLeaves ? medicalLeaves : medicalBalance;
        final emergencyUsed = emergencyBalance > emergencyLeaves ? emergencyLeaves : emergencyBalance;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.analytics,
                      color: Color(0xFFD40511),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Leave Analysis',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Leave Balance Card with Bar Charts
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Balance & Usage',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Annual Leave Bar
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Annual Leave')),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProgressBar(
                                  current: annualUsed.toDouble(), 
                                  total: annualBalance.toDouble(),
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Used: $annualUsed days',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Balance: ${annualBalance - annualUsed} days',
                                      style: const TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Medical Leave Bar
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Medical Leave')),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProgressBar(
                                  current: medicalUsed.toDouble(), 
                                  total: medicalBalance.toDouble(),
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Used: $medicalUsed days',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Balance: ${medicalBalance - medicalUsed} days',
                                      style: const TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Emergency Leave Bar
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Emergency Leave')),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProgressBar(
                                  current: emergencyUsed.toDouble(), 
                                  total: emergencyBalance.toDouble(),
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Used: $emergencyUsed days',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Balance: ${emergencyBalance - emergencyUsed} days',
                                      style: const TextStyle(
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.info_outline, size: 16),
                          label: const Text('Learn about leave policies'),
                          onPressed: () {
                            _showLeavePolicy();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Leave Applications Summary Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Applications Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Status Distribution
                      Row(
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
                      const SizedBox(height: 16),
                      
                      // Approval Rate
                      const Text(
                        'Approval Rate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: totalLeaves > 0 ? approvedLeaves / totalLeaves : 0,
                        backgroundColor: Colors.grey[200],
                        color: approvedLeaves > 0 ? Colors.green : Colors.grey,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalLeaves > 0 
                            ? '${(approvedLeaves / totalLeaves * 100).toStringAsFixed(1)}% of your leave applications have been approved'
                            : 'No leave applications yet',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Leave Type Distribution Card
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
                              if (annualLeaves > 0)
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
                              if (medicalLeaves > 0)
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
                              if (emergencyLeaves > 0)
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
                          _buildLegendItem('Annual Leave', const Color(0xFF1976D2)),
                          const SizedBox(width: 20),
                          _buildLegendItem('Medical Leave', const Color(0xFF9C27B0)),
                          const SizedBox(width: 20),
                          _buildLegendItem('Emergency Leave', const Color(0xFFFFB300)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        );
      },
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
                    // Navigate to change password screen with current user's email
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FirstTimePasswordChangeScreen(
                          email: _userEmail,
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
                        'Preferences',
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
  leading: const Icon(Icons.notifications, color: Color(0xFF9C27B0)),
  title: const Text('Notification Settings'),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EmployeeNotificationSettingsScreen(),
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
                        Icons.help_outline,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Help & Support',
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
                  leading: const Icon(Icons.info_outline, color: Color(0xFF1976D2)),
                  title: const Text('About'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Show about dialog
                    showAboutDialog(
                      context: context,
                      applicationName: 'DHL Leave Management',
                      applicationVersion: '1.0.0',
                      applicationIcon: Image.asset(
                        'assets/DHL_Express_logo_rgb.png',
                        height: 50,
                      ),
                      applicationLegalese: '© 2025 DHL Express. All rights reserved.',
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.contact_support, color: Color(0xFF43A047)),
                  title: const Text('Contact HR'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showContactHRDialog();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description, color: Color(0xFF9C27B0)),
                  title: const Text('Leave Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showLeavePolicy();
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  // Helper widgets
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressBar({
    required double current,
    required double total,
    required Color color,
  }) {
    return Stack(
      children: [
        // Background
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        // Progress
        Container(
          height: 10,
          width: total > 0 ? (current / total) * MediaQuery.of(context).size.width * 0.6 : 0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
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
  
  Widget _buildLeaveBalanceItem(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
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
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
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
      case 'Cancelled':
        color = Colors.grey;
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
  
  Color _getLeaveTypeColor(String leaveType) {
    if (leaveType.toLowerCase().contains('annual')) {
      return const Color(0xFF1976D2); // Blue
    } else if (leaveType.toLowerCase().contains('medical')) {
      return const Color(0xFF9C27B0); // Purple
    } else if (leaveType.toLowerCase().contains('emergency')) {
      return const Color(0xFFFFB300); // Orange
    } else {
      return Colors.grey;
    }
  }
  
  IconData _getLeaveTypeIcon(String leaveType) {
    if (leaveType.toLowerCase().contains('annual')) {
      return Icons.beach_access;
    } else if (leaveType.toLowerCase().contains('medical')) {
      return Icons.medical_services;
    } else if (leaveType.toLowerCase().contains('emergency')) {
      return Icons.warning_amber_rounded;
    } else {
      return Icons.event_note;
    }
  }
  
  // Dialog methods
  void _showLeavePolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.description, color: Color(0xFFD40511)),
            const SizedBox(width: 8),
            const Text('DHL Leave Policy'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Annual Leave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '• Every employee is entitled to 21 days of annual leave per calendar year\n'
                '• Annual leave should be applied at least 7 days in advance\n'
                '• Unused annual leave can be carried forward to the next year (max 7 days)',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Medical Leave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '• Employees are entitled to 14 days of medical leave per year\n'
                '• Medical certificate is required for leaves more than 2 consecutive days\n'
                '• Medical leave does not carry forward to the next year',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Emergency Leave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '• 5 days of emergency leave are provided annually\n'
                '• To be used for unforeseen emergencies only\n'
                '• Supporting documents may be required in some cases',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 16),
              const Text(
                'Application Process',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '• All leave applications are subject to approval by HR\n'
                '• HR will process leave applications within 2 working days\n'
                '• Employees can cancel pending leave applications',
                style: TextStyle(color: Colors.grey[800]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showContactHRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.contact_support, color: Color(0xFFD40511)),
            const SizedBox(width: 8),
            const Text('Contact HR Department'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Color(0xFF1976D2)),
              title: const Text('Email'),
              subtitle: const Text('hr@dhl.com'),
              onTap: () {
                // Launch email client
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email client functionality will be available soon')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.phone, color: Color(0xFF43A047)),
              title: const Text('Phone'),
              subtitle: const Text('+1-800-123-4567'),
              onTap: () {
                // Launch phone dialer
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone dialer functionality will be available soon')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFFFFA000)),
              title: const Text('Chat with HR Bot'),
              subtitle: const Text('Get instant answers to common questions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatbotScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showCancelLeaveDialog(String leaveId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Leave Application'),
        content: const Text('Are you sure you want to cancel this leave application? This will remove your request from HR review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update leave status to "Cancelled"
                await _firebaseService.updateLeaveStatus(
                  leaveId,
                  'Cancelled',
                );
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leave application cancelled successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error cancelling application: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}