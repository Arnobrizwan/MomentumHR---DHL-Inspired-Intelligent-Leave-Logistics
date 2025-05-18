import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

class LeaveApplicationForm extends StatefulWidget {
  final String? employeeId; // Optional - for HR to create on behalf of employee
  final String? employeeName; // Optional - for HR to create on behalf of employee
  
  const LeaveApplicationForm({
    super.key,
    this.employeeId,
    this.employeeName,
  });

  @override
  State<LeaveApplicationForm> createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  final _leaveTypes = ['Annual Leave', 'Medical Leave', 'Emergency Leave'];
  
  String _employeeId = '';
  String _employeeName = '';
  String _leaveType = 'Annual Leave';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  String _reason = '';
  bool _isHR = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _checkIfHR();
    
    // If employeeId and name are provided (HR creating for employee)
    if (widget.employeeId != null && widget.employeeName != null) {
      setState(() {
        _employeeId = widget.employeeId!;
        _employeeName = widget.employeeName!;
        _isLoading = false;
      });
    } else {
      _loadEmployeeData();
    }
  }
  
  Future<void> _checkIfHR() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _isHR = userDoc.data()?['userType'] == 'HR_ADMIN';
        });
      }
    }
  }
  
  Future<void> _loadEmployeeData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final String? employeeId = userDoc.data()?['employeeId'];
      if (employeeId == null) {
        setState(() {
          _employeeName = userDoc.data()?['name'] ?? 'Unknown';
          _isLoading = false;
        });
        return;
      }
      
      // Get employee data
      final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
      if (employeeDoc.exists) {
        setState(() {
          _employeeId = employeeId;
          _employeeName = employeeDoc.data()?['name'] ?? userDoc.data()?['name'] ?? 'Unknown';
        });
      } else {
        setState(() {
          _employeeName = userDoc.data()?['name'] ?? 'Unknown';
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
            content: Text('Error loading employee data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID is required. Please contact HR.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Check if there are overlapping leave applications
      final overlappingLeaves = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: _employeeId)
          .where('status', isNotEqualTo: 'Rejected')
          .get();
      
      // Check if any of the existing leaves overlap with the new one
      bool hasOverlap = false;
      for (var doc in overlappingLeaves.docs) {
        final Timestamp startTimestamp = doc['startDate'];
        final Timestamp endTimestamp = doc['endDate'];
        final DateTime existingStart = startTimestamp.toDate();
        final DateTime existingEnd = endTimestamp.toDate();
        
        // Check for overlap
        if ((_startDate.isBefore(existingEnd) || _startDate.isAtSameMomentAs(existingEnd)) &&
            (_endDate.isAfter(existingStart) || _endDate.isAtSameMomentAs(existingStart))) {
          hasOverlap = true;
          break;
        }
      }
      
      if (hasOverlap) {
        setState(() {
          _isSubmitting = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have an approved or pending leave during this period.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Create a unique ID for the leave application
      final String leaveId = '${_employeeId}_${_startDate.millisecondsSinceEpoch}_${_endDate.millisecondsSinceEpoch}';
      
      // Create leave application document
      await _firestore.collection('leaveApplications').doc(leaveId).set({
        'employeeId': _employeeId,
        'employeeName': _employeeName,
        'leaveType': _leaveType,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'reason': _reason,
        'status': 'Pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': _auth.currentUser?.uid ?? '',
      });
      
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting leave application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  int _calculateLeaveDuration() {
    // Count only weekdays (Mon-Fri) between start and end dates
    int days = 0;
    DateTime date = _startDate;
    while (date.isBefore(_endDate) || date.isAtSameMomentAs(_endDate)) {
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
        title: const Text('Apply for Leave'),
        backgroundColor: const Color(0xFFD40511), // DHL Red
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
                    // Employee Info Card
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Employee Name
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Name: $_employeeName',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Employee ID
                            Row(
                              children: [
                                const Icon(Icons.badge, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'ID: ${_employeeId.isNotEmpty ? _employeeId : "Not assigned"}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Leave Details Card
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Leave Type
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Leave Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              value: _leaveType,
                              items: _leaveTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _leaveType = value!;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a leave type';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Start Date
                            GestureDetector(
                              onTap: () {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: DateTime.now(),
                                  maxTime: DateTime.now().add(const Duration(days: 365)),
                                  onConfirm: (date) {
                                    setState(() {
                                      _startDate = date;
                                      // If end date is before start date, update it
                                      if (_endDate.isBefore(_startDate)) {
                                        _endDate = _startDate;
                                      }
                                    });
                                  },
                                  currentTime: _startDate,
                                  locale: LocaleType.en,
                                );
                              },
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat('EEEE, MMMM d, yyyy').format(_startDate),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a start date';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // End Date
                            GestureDetector(
                              onTap: () {
                                DatePicker.showDatePicker(
                                  context,
                                  showTitleActions: true,
                                  minTime: _startDate,
                                  maxTime: _startDate.add(const Duration(days: 365)),
                                  onConfirm: (date) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  },
                                  currentTime: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                                  locale: LocaleType.en,
                                );
                              },
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'End Date',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat('EEEE, MMMM d, yyyy').format(_endDate),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an end date';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Leave Duration
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, color: Color(0xFFD40511)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duration: ${_calculateLeaveDuration()} working day(s)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Reason
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Reason for Leave',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                              onChanged: (value) {
                                setState(() {
                                  _reason = value;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please provide a reason for your leave';
                                }
                                if (value.length < 5) {
                                  return 'Reason should be at least 5 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitLeaveApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD40511), // DHL Red
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Leave Application',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Leave Policy Information
                    Card(
                      elevation: 1,
                      color: Colors.yellow.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber),
                                SizedBox(width: 8),
                                Text(
                                  'Leave Policy Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Annual Leave: Maximum 14 days per year',
                              style: TextStyle(fontSize: 14),
                            ),
                            const Text(
                              '• Medical Leave: Requires medical certificate for 2+ days',
                              style: TextStyle(fontSize: 14),
                            ),
                            const Text(
                              '• Emergency Leave: Limited to 3 days per year',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Applications should be submitted at least 7 days in advance for Annual Leave.',
                              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          ],
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