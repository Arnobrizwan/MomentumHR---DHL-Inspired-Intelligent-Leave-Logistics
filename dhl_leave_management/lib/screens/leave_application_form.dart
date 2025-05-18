import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

class LeaveApplicationForm extends StatefulWidget {
  final String? employeeId;
  final String? employeeName;

  const LeaveApplicationForm({super.key, this.employeeId, this.employeeName});

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
  bool _authChecked = false;

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
            content: Text('You need to be logged in to submit leave applications'),
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
    
    // Continue with regular initialization
    _checkIfHR();
    if (widget.employeeId != null && widget.employeeName != null) {
      setState(() {
        _employeeId = widget.employeeId!;
        _employeeName = widget.employeeName!;
        _isLoading = false;
        _authChecked = true;
      });
      print('Initialized with provided employee: $_employeeId - $_employeeName');
    } else {
      _loadEmployeeData();
    }
  }

  Future<void> _checkIfHR() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _isHR = userDoc.data()?['userType'] == 'HR_ADMIN';
          });
          print('User is HR Admin: $_isHR');
        } else {
          print('User document not found: ${user.uid}');
        }
      } catch (e) {
        print('Error checking HR status: $e');
      }
    }
  }

  Future<void> _loadEmployeeData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No current user found');
        setState(() => _isLoading = false);
        return;
      }

      print('Loading data for user: ${user.uid}');
      
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (!userDoc.exists) {
          print('User document does not exist for ID: ${user.uid}');
          setState(() {
            _employeeId = user.uid;
            _employeeName = user.displayName ?? user.email ?? 'Unknown User';
            _isLoading = false;
            _authChecked = true;
          });
          return;
        }
        
        final employeeId = userDoc.data()?['employeeId'] ?? '';
        final name = userDoc.data()?['name'] ?? user.displayName ?? user.email ?? '';
        
        print('User document data: ${userDoc.data()}');

        if (employeeId.isNotEmpty) {
          print('Found employee ID: $employeeId, fetching employee details');
          
          try {
            final empDoc = await _firestore.collection('employees').doc(employeeId).get();
            final empName = empDoc.exists ? (empDoc.data()?['name'] ?? name) : name;
            
            print('Employee document data: ${empDoc.data()}');
            
            setState(() {
              _employeeId = employeeId;
              _employeeName = empName;
              _isLoading = false;
              _authChecked = true;
            });
            print('Set employee data: $_employeeId - $_employeeName');
          } catch (empError) {
            print('Error fetching employee: $empError');
            setState(() {
              _employeeId = employeeId;
              _employeeName = name;
              _isLoading = false;
              _authChecked = true;
            });
          }
        } else {
          print('No employee ID found, using user info instead');
          setState(() {
            _employeeId = user.uid;
            _employeeName = name;
            _isLoading = false;
            _authChecked = true;
          });
        }
      } catch (docError) {
        print('Error fetching user document: $docError');
        setState(() {
          _employeeId = user.uid;
          _employeeName = user.displayName ?? user.email ?? 'Unknown User';
          _isLoading = false;
          _authChecked = true;
        });
      }
    } catch (e) {
      print('Error loading employee data: $e');
      setState(() {
        _isLoading = false;
        _authChecked = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (!_authChecked || !_formKey.currentState!.validate()) {
      print('Form validation failed or auth not checked');
      return;
    }
    
    // Verify user is authenticated
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to submit leave applications'),
          backgroundColor: Colors.red,
        ),
      );
      print('Cannot submit: not authenticated');
      return;
    }
    
    // Add validation for employee ID and name
    if (_employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID is missing. Please reload the form.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Cannot submit: employee ID is empty');
      return;
    }
    
    if (_employeeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee Name is missing. Please reload the form.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Cannot submit: employee name is empty');
      return;
    }

    setState(() => _isSubmitting = true);
    print('Starting leave application submission');
    print('Employee ID: $_employeeId');
    print('Employee Name: $_employeeName');
    print('Leave Type: $_leaveType');
    print('Dates: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}');

    try {
      // Create a simpler query first to test Firestore access
      print('Testing Firestore access...');
      try {
        final testQuery = await _firestore.collection('leaveApplications').limit(1).get();
        print('Firestore test query successful. Documents: ${testQuery.docs.length}');
      } catch (testError) {
        print('Firestore test query failed: $testError');
        throw Exception('Database access error. Please try again later.');
      }
      
      // Check for overlapping leaves - but with error handling for index issues
      print('Checking for overlapping leave applications');
      List<DocumentSnapshot> overlapDocs = [];
      
      try {
        final overlapQuery = await _firestore
            .collection('leaveApplications')
            .where('employeeId', isEqualTo: _employeeId)
            .where('status', isNotEqualTo: 'Rejected')
            .get();
        
        overlapDocs = overlapQuery.docs;
        print('Successfully queried for overlaps. Found ${overlapDocs.length} docs');
      } catch (queryError) {
        print('Error with overlap query, possibly missing index: $queryError');
        // Try a simpler query instead that doesn't require the compound index
        try {
          final simpleQuery = await _firestore
              .collection('leaveApplications')
              .where('employeeId', isEqualTo: _employeeId)
              .get();
          
          // Filter in code instead of in query
          overlapDocs = simpleQuery.docs.where((doc) => 
            doc['status'] != 'Rejected').toList();
          
          print('Used fallback query for overlaps. Found ${overlapDocs.length} docs');
        } catch (fallbackError) {
          print('Even fallback query failed: $fallbackError');
          throw Exception('Failed to check for existing leave applications');
        }
      }

      // Now check for overlaps in the results we got
      bool hasOverlap = false;
      for (var doc in overlapDocs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        final Timestamp? startTs = data['startDate'] as Timestamp?;
        final Timestamp? endTs = data['endDate'] as Timestamp?;
        
        if (startTs == null || endTs == null) {
          print('Skipping document with missing dates: ${doc.id}');
          continue; // Skip invalid records
        }
        
        final existingStart = startTs.toDate();
        final existingEnd = endTs.toDate();
        
        print('Checking overlap with leave: ${DateFormat('yyyy-MM-dd').format(existingStart)} to ${DateFormat('yyyy-MM-dd').format(existingEnd)}');
        
        if ((_startDate.isBefore(existingEnd) || _startDate.isAtSameMomentAs(existingEnd)) &&
            (_endDate.isAfter(existingStart) || _endDate.isAtSameMomentAs(existingStart))) {
          hasOverlap = true;
          print('Overlap detected!');
          break;
        }
      }

      if (hasOverlap) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have a leave during this period.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create leave application ID
      final String id = '${_employeeId}_${_startDate.millisecondsSinceEpoch}_${_endDate.millisecondsSinceEpoch}';
      print('Generated leave application ID: $id');
      
      // Create the document data explicitly
      final Map<String, dynamic> leaveData = {
        'employeeId': _employeeId.trim(),
        'employeeName': _employeeName.trim(),
        'leaveType': _leaveType,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'reason': _reason.trim(),
        'status': 'Pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': _auth.currentUser?.uid ?? 'unknown',
      };
      
      print('Saving leave application with data: $leaveData');

      // Save to Firestore with explicit error handling
      try {
        await _firestore.collection('leaveApplications').doc(id).set(leaveData);
        print('Leave application saved successfully');
      } catch (firestoreError) {
        print('Firestore error: $firestoreError');
        throw Exception('Error saving to database: $firestoreError');
      }

      setState(() => _isSubmitting = false);
      
      // Verify the document was created with proper data
      try {
        final verifyDoc = await _firestore.collection('leaveApplications').doc(id).get();
        if (verifyDoc.exists) {
          print('Document verified: ${verifyDoc.data()}');
        } else {
          print('Warning: Document was not found after creation!');
        }
      } catch (verifyError) {
        print('Error verifying document: $verifyError');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('Error in submission process: $e');
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
    }
  }

  int _calculateLeaveDuration() {
    int days = 0;
    DateTime date = _startDate;
    while (!date.isAfter(_endDate)) {
      if (date.weekday < 6) days++;
      date = date.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
        backgroundColor: const Color(0xFFD40511),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD40511)))
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
                      const Text('You need to be logged in to submit leave applications'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD40511)),
                        child: const Text('Return to Login'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display employee info with validation
                        if (_employeeName.isEmpty)
                          const Text('⚠️ Warning: Employee name not available',
                              style: TextStyle(color: Colors.red, fontSize: 16))
                        else
                          Text('Name: $_employeeName', style: const TextStyle(fontSize: 16)),
                          
                        if (_employeeId.isEmpty)
                          const Text('⚠️ Warning: Employee ID not available',
                              style: TextStyle(color: Colors.red, fontSize: 16))
                        else
                          Text('ID: $_employeeId', style: const TextStyle(fontSize: 16)),
                          
                        const SizedBox(height: 16),
                        DropdownButtonFormField(
                          value: _leaveType,
                          decoration: const InputDecoration(labelText: 'Leave Type'),
                          items: _leaveTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                          onChanged: (value) => setState(() => _leaveType = value as String),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          readOnly: true,
                          onTap: () => DatePicker.showDatePicker(
                            context, 
                            currentTime: _startDate,
                            onConfirm: (d) => setState(() {
                              _startDate = d;
                              // If end date is before start date, adjust it
                              if (_endDate.isBefore(_startDate)) {
                                _endDate = _startDate.add(const Duration(days: 1));
                              }
                            }),
                          ),
                          controller: TextEditingController(text: DateFormat('yyyy-MM-dd').format(_startDate)),
                          decoration: const InputDecoration(labelText: 'Start Date'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          readOnly: true,
                          onTap: () => DatePicker.showDatePicker(
                            context, 
                            currentTime: _endDate,
                            // Ensure minimum date is the start date
                            minTime: _startDate,
                            onConfirm: (d) => setState(() => _endDate = d),
                          ),
                          controller: TextEditingController(text: DateFormat('yyyy-MM-dd').format(_endDate)),
                          decoration: const InputDecoration(labelText: 'End Date'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Duration: ${_calculateLeaveDuration()} working day(s)',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Reason for Leave'),
                          onChanged: (v) => _reason = v,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitLeaveApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD40511),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Submit Application', style: TextStyle(fontSize: 16)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
    );
  }
}