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
  Map<String, dynamic>? _leaveData;
  String? _rejectReason;
  String? _employeeEmail;
  
  @override
  void initState() {
    super.initState();
    _checkIfHR();
    _loadLeaveData();
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
        }
      }
    } catch (e) {
      // Continue with default value (false) if error occurs
    }
  }
  
  Future<void> _loadLeaveData() async {
    try {
      final leaveDoc = await _firestore.collection('leaveApplications').doc(widget.leaveId).get();
      
      if (!leaveDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get employee email
      final employeeId = leaveDoc.data()?['employeeId'];
      if (employeeId != null) {
        // First try to get it from users collection
        final userQuery = await _firestore
            .collection('users')
            .where('employeeId', isEqualTo: employeeId)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          setState(() {
            _employeeEmail = userQuery.docs.first.data()['email'];
          });
        } else {
          // If not found, try to get from employees collection
          final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
          if (employeeDoc.exists) {
            setState(() {
              _employeeEmail = employeeDoc.data()?['email'];
            });
          }
        }
      }
      
      setState(() {
        _leaveData = leaveDoc.data();
        _isLoading = false;
      });
    } catch (e) {
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
      // Update leave status
      await _firestore.collection('leaveApplications').doc(widget.leaveId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
        if (status == 'Rejected') 'rejectReason': _rejectReason,
      });
      
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
      // Delete the leave application
      await _firestore.collection('leaveApplications').doc(widget.leaveId).delete();
      
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
          : _leaveData == null
              ? const Center(
                  child: Text('Leave application not found'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Card(
                        elevation: 3,
                        color: _getStatusColor(_leaveData!['status']).withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getStatusColor(_leaveData!['status']),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(_leaveData!['status']),
                                color: _getStatusColor(_leaveData!['status']),
                                size: 40,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _leaveData!['status'],
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(_leaveData!['status']),
                                      ),
                                    ),
                                    if (_leaveData!['status'] == 'Rejected' && _leaveData!['rejectReason'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Reason: ${_leaveData!['rejectReason']}',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Employee Information
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Employee Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                icon: Icons.person,
                                label: 'Name',
                                value: _leaveData!['employeeName'],
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                icon: Icons.badge,
                                label: 'Employee ID',
                                value: _leaveData!['employeeId'],
                              ),
                              if (_employeeEmail != null) ...[
                                const SizedBox(height: 8),
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
                      const SizedBox(height: 16),
                      
                      // Leave Details
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Leave Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                icon: Icons.category,
                                label: 'Leave Type',
                                value: _leaveData!['leaveType'],
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                icon: Icons.calendar_today,
                                label: 'Duration',
                                value: '${_calculateLeaveDuration()} working day(s)',
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                icon: Icons.date_range,
                                label: 'Start Date',
                                value: DateFormat('EEEE, MMMM d, yyyy').format(
                                  (_leaveData!['startDate'] as Timestamp).toDate(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                icon: Icons.date_range,
                                label: 'End Date',
                                value: DateFormat('EEEE, MMMM d, yyyy').format(
                                  (_leaveData!['endDate'] as Timestamp).toDate(),
                                ),
                              ),
                              if (_leaveData!['reason'] != null) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Reason for Leave',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_leaveData!['reason']),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Application Timeline
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Application Timeline',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTimelineItem(
                                title: 'Application Submitted',
                                date: (_leaveData!['createdAt'] as Timestamp).toDate(),
                                isCompleted: true,
                              ),
                              _buildTimelineItem(
                                title: 'Status: ${_leaveData!['status']}',
                                date: _leaveData!['updatedAt'] != null
                                    ? (_leaveData!['updatedAt'] as Timestamp).toDate()
                                    : null,
                                isCompleted: _leaveData!['status'] != 'Pending',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // HR Actions
                      if (_isHR && _leaveData!['status'] == 'Pending') ...[
                        const SizedBox(height: 32),
                        const Text(
                          'HR Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Employee Actions
                      if (!_isHR && _leaveData!['status'] == 'Pending') ...[
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _cancelLeaveApplication,
                            icon: const Icon(Icons.delete),
                            label: const Text('Cancel Leave Application'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimelineItem({
    required String title,
    required DateTime? date,
    required bool isCompleted,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
                border: Border.all(
                  color: isCompleted ? Colors.green.shade700 : Colors.grey,
                  width: 2,
                ),
              ),
              child: isCompleted 
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy - h:mm a').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.grey : Colors.grey.shade400,
                  ),
                ),
              ],
              const SizedBox(height: 16),
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