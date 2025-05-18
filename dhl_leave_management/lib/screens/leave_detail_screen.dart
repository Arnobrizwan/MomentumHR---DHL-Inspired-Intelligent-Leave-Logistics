import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LeaveDetailScreen extends StatefulWidget {
  final String leaveId;
  
  const LeaveDetailScreen({
    super.key,
    required this.leaveId,
  });

  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isHR = false;
  bool _authChecked = false;
  Map<String, dynamic>? _leaveData;
  String? _rejectReason;
  String? _employeeEmail;
  
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }
  
  Future<void> _checkAuthentication() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user found');
      setState(() {
        _isLoading = false;
        _authChecked = true;
      });
      
      // Show authentication error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to view leave details'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        
        // Return to previous screen after delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop();
        });
      });
      return;
    }
    
    print('Authenticated user: ${user.uid}, email: ${user.email}');
    _authChecked = true;
    
    // Continue with regular initialization
    await _checkIfHR();
    await _loadLeaveData();
  }
  
  Future<void> _checkIfHR() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _isHR = userDoc.data()?['userType'] == 'HR_ADMIN';
          });
          print('User is HR Admin: $_isHR');
        } else {
          print('User document not found: ${user.uid}');
        }
      }
    } catch (e) {
      print('Error checking HR status: $e');
      // Continue with default value (false) if error occurs
    }
  }
  
  Future<void> _loadLeaveData() async {
    if (!_authChecked) {
      print('Skipping data load - authentication not checked');
      return;
    }
    
    try {
      print('Loading leave data for ID: ${widget.leaveId}');
      
      // Test Firestore access first
      try {
        final testQuery = await _firestore.collection('leaveApplications').limit(1).get();
        print('Firestore test query successful. Documents: ${testQuery.docs.length}');
      } catch (testError) {
        print('Firestore test query failed: $testError');
        throw Exception('Database access error. Please try again later.');
      }
      
      final leaveDoc = await _firestore.collection('leaveApplications').doc(widget.leaveId).get();
      
      if (!leaveDoc.exists) {
        print('Leave document not found: ${widget.leaveId}');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      print('Leave document found: ${leaveDoc.id}');
      print('Document data: ${leaveDoc.data()}');
      
      // Get employee email
      final employeeId = leaveDoc.data()?['employeeId'];
      if (employeeId != null) {
        // First try to get it from users collection
        try {
          final userQuery = await _firestore
              .collection('users')
              .where('employeeId', isEqualTo: employeeId)
              .limit(1)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            setState(() {
              _employeeEmail = userQuery.docs.first.data()['email'];
            });
            print('Found employee email from users collection: $_employeeEmail');
          } else {
            // If not found, try to get from employees collection
            final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
            if (employeeDoc.exists) {
              setState(() {
                _employeeEmail = employeeDoc.data()?['email'];
              });
              print('Found employee email from employees collection: $_employeeEmail');
            } else {
              print('Employee document not found: $employeeId');
            }
          }
        } catch (emailError) {
          print('Error fetching employee email: $emailError');
        }
      }
      
      setState(() {
        _leaveData = leaveDoc.data();
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading leave data: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading leave data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _updateLeaveStatus(String status) async {
    if (status == 'Rejected' && (_rejectReason == null || _rejectReason!.isEmpty)) {
      _showRejectReasonDialog();
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      print('Updating leave status to: $status');
      
      final updateData = {
        'status': status,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      };
      
      if (status == 'Rejected' && _rejectReason != null) {
        updateData['rejectReason'] = _rejectReason;
      }
      
      // Update leave status
      await _firestore.collection('leaveApplications').doc(widget.leaveId).update(updateData);
      print('Leave status updated successfully');
      
      setState(() {
        if (_leaveData != null) {
          _leaveData!['status'] = status;
          if (status == 'Rejected') {
            _leaveData!['rejectReason'] = _rejectReason;
          }
        }
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave application $status successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating leave status: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating leave status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _cancelLeaveApplication() async {
    final bool confirm = await _showConfirmDialog(
      title: 'Cancel Leave Application',
      content: 'Are you sure you want to cancel this leave application? This action cannot be undone.',
    );
    
    if (!confirm) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      print('Canceling leave application: ${widget.leaveId}');
      
      // Delete the leave application
      await _firestore.collection('leaveApplications').doc(widget.leaveId).delete();
      print('Leave application canceled successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application canceled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error canceling leave application: $e');
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error canceling leave application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _showRejectReasonDialog() async {
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
                  setState(() {
                    _rejectReason = reasonController.text.trim();
                  });
                  Navigator.of(context).pop();
                  _updateLeaveStatus('Rejected');
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
  
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }
  
  int _calculateLeaveDuration() {
    if (_leaveData == null) return 0;
    
    final startDate = (_leaveData!['startDate'] as Timestamp).toDate();
    final endDate = (_leaveData!['endDate'] as Timestamp).toDate();
    
    // Count only weekdays (Mon-Fri) between start and end dates
    int days = 0;
    DateTime date = startDate;
    while (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) {
      if (date.weekday < 6) { // Weekdays only (1=Monday, 7=Sunday)
        days++;
      }
      date = date.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Details'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
        actions: [
          if (!_isLoading && _leaveData != null && _leaveData!['status'] == 'Pending' && !_isHR)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isProcessing ? null : _cancelLeaveApplication,
              tooltip: 'Cancel Application',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD40511), // DHL Red
              ),
            )
          : !_authChecked || _auth.currentUser == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Authentication Required',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('You need to be logged in to view leave details'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD40511)),
                        child: const Text('Return to Login'),
                      ),
                    ],
                  ),
                )
              : _leaveData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Leave Application Not Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID: ${widget.leaveId}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD40511)),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Status Card
                          Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getStatusColor(_leaveData!['status']).withOpacity(0.8),
                                    _getStatusColor(_leaveData!['status']).withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getStatusIcon(_leaveData!['status']),
                                            color: _getStatusColor(_leaveData!['status']),
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _leaveData!['status'],
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (_leaveData!['status'] == 'Rejected' && _leaveData!['rejectReason'] != null) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                                                child: Text(
                                                  '${_leaveData!['rejectReason']}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (_leaveData!['status'] == 'Pending')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer,
                                              size: 14,
                                              color: _getStatusColor(_leaveData!['status']),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Awaiting Approval',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _getStatusColor(_leaveData!['status']),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Enhanced Employee Information Card
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD40511).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFFD40511),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Employee Information',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'Name',
                                    value: _leaveData!['employeeName'] ?? 'Unknown',
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.badge,
                                    label: 'Employee ID',
                                    value: _leaveData!['employeeId'] ?? 'Unknown',
                                  ),
                                  if (_employeeEmail != null) ...[
                                    const Divider(height: 24),
                                    _buildInfoRow(
                                      icon: Icons.email,
                                      label: 'Email',
                                      value: _employeeEmail!,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          // Enhanced Leave Details Card
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD40511).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFFD40511),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Leave Details',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildInfoRow(
                                    icon: Icons.category,
                                    label: 'Leave Type',
                                    value: _leaveData!['leaveType'] ?? 'Unknown',
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: 'Duration',
                                    value: '${_calculateLeaveDuration()} working day(s)',
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.date_range,
                                    label: 'Start Date',
                                    value: _leaveData!['startDate'] != null 
                                      ? DateFormat('EEEE, MMMM d, yyyy').format(
                                          (_leaveData!['startDate'] as Timestamp).toDate(),
                                        )
                                      : 'Unknown',
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.date_range,
                                    label: 'End Date',
                                    value: _leaveData!['endDate'] != null
                                      ? DateFormat('EEEE, MMMM d, yyyy').format(
                                          (_leaveData!['endDate'] as Timestamp).toDate(),
                                        )
                                      : 'Unknown',
                                  ),
                                  if (_leaveData!['reason'] != null && _leaveData!['reason'].toString().isNotEmpty) ...[
                                    const Divider(height: 24),
                                    const Text(
                                      'Reason for Leave',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF666666),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Text(
                                        _leaveData!['reason'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          // Enhanced Application Timeline
                          Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD40511).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.history,
                                          color: Color(0xFFD40511),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Application Timeline',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green,
                                              border: Border.all(color: Colors.white, width: 3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey.withOpacity(0.3),
                                                  spreadRadius: 1,
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          Container(
                                            width: 3,
                                            height: 50,
                                            color: _leaveData!['status'] != 'Pending' 
                                                ? Colors.green 
                                                : Colors.grey.shade300,
                                          ),
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _leaveData!['status'] != 'Pending' 
                                                  ? _getStatusColor(_leaveData!['status']) 
                                                  : Colors.grey.shade300,
                                              border: Border.all(
                                                color: Colors.white, 
                                                width: 3
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.grey.withOpacity(0.3),
                                                  spreadRadius: 1,
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              _leaveData!['status'] == 'Approved' 
                                                  ? Icons.check_circle 
                                                  : _leaveData!['status'] == 'Rejected' 
                                                      ? Icons.cancel 
                                                      : Icons.hourglass_empty,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Application Submitted',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _leaveData!['createdAt'] != null 
                                                    ? DateFormat('MMM d, yyyy - h:mm a').format(
                                                        (_leaveData!['createdAt'] as Timestamp).toDate(),
                                                      )
                                                    : 'Unknown date',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 36),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _leaveData!['status'] == 'Pending' 
                                                      ? 'Waiting for Review' 
                                                      : 'Application ${_leaveData!['status']}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: _leaveData!['status'] != 'Pending' 
                                                        ? _getStatusColor(_leaveData!['status']) 
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (_leaveData!['updatedAt'] != null && _leaveData!['status'] != 'Pending')
                                                  Text(
                                                    DateFormat('MMM d, yyyy - h:mm a').format(
                                                      (_leaveData!['updatedAt'] as Timestamp).toDate(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // HR Actions
                          if (_isHR && _leaveData!['status'] == 'Pending') ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                            Text(
                              'HR Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _updateLeaveStatus('Rejected'),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _updateLeaveStatus('Approved'),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Employee Actions
                          if (!_isHR && _leaveData!['status'] == 'Pending') ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : _cancelLeaveApplication,
                                icon: const Icon(Icons.delete),
                                label: const Text('Cancel Leave Application'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                          
                          // Spacing at the bottom
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }
  
  // Enhanced info row builder
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFD40511), size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending_actions;
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}