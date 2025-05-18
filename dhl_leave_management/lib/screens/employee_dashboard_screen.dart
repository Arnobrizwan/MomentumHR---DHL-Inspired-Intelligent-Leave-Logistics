import 'package:flutter/material.dart';
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
  Map<String, dynamic>? _userDetails;
  
  // Status filter for leave applications
  String _leaveStatusFilter = 'All';
  
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
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (userDetails != null) {
        setState(() {
          _userName = userDetails['name'] ?? 'Employee';
          _employeeId = userDetails['id'] ?? '';
          _userEmail = currentUser?.email ?? '';
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
                  Icons.settings,
                  color: _selectedIndex == 2 ? const Color(0xFFD40511) : Colors.grey[700],
                ),
                title: Text(
                  'Settings',
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
      // Add FAB for quick actions - apply for leave
      floatingActionButton: _selectedIndex != 2
          ? FloatingActionButton(
              onPressed: _applyForLeave,
              backgroundColor: const Color(0xFFD40511),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
  
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildMyApplications();
      case 2:
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
              final annualBalance = stats['balance']?['annual'] ?? 0;
              final medicalBalance = stats['balance']?['medical'] ?? 0;
              final emergencyBalance = stats['balance']?['emergency'] ?? 0;
              
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
          
          // Leave applications
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
                        Text(
                          'No $_leaveStatusFilter applications found',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _leaveStatusFilter = 'All';
                            });
                          },
                          child: const Text('Clear Filter'),
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
                    // Navigate to notification settings - implement this screen if needed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings will be available soon'),
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
                    // Contact HR - implement this if needed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contact HR feature will be available soon'),
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
  
  // Helper widgets
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
      return const Color(0xFF1976D2);
    } else if (leaveType.toLowerCase().contains('medical')) {
      return const Color(0xFF9C27B0);
    } else if (leaveType.toLowerCase().contains('emergency')) {
      return const Color(0xFFFFB300);
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
                // Since FirebaseService doesn't have cancelLeaveApplication,
                // we can use updateLeaveStatus instead with a "Cancelled" status
                await _firebaseService.updateLeaveStatus(
                  leaveId,
                  'Cancelled',  // Change status to 'Cancelled'
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