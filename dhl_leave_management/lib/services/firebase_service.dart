import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'dart:typed_data';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default leave balances - these would typically come from company policy
  // and might be different for different employees or roles
  static const Map<String, int> defaultLeaveBalances = {
    'annual': 21,
    'medical': 14,
    'emergency': 5,
  };

  // ────────────────────────────────────────────────────────────────────────────
  // Leave Applications
  // ────────────────────────────────────────────────────────────────────────────
  
  // Get all leave applications
  Stream<List<LeaveApplication>> getAllLeaveApplications() {
    try {
      return _firestore
          .collection('leaveApplications')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            print("Error in getAllLeaveApplications: $error");
            // Return empty list on error instead of breaking the stream
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
            } catch (e) {
              print("Error mapping documents in getAllLeaveApplications: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }

  // Get leave applications for specific employee
  Stream<List<LeaveApplication>> getEmployeeLeaveApplications(String employeeId) {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployeeLeaveApplications");
        return Stream.value([]);  // Return empty stream for empty ID
      }
      
      print("Fetching leave applications for employee: $employeeId");
      
      return _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            print("Error in getEmployeeLeaveApplications for $employeeId: $error");
            // Check if error is about missing index
            if (error.toString().contains('index')) {
              print("This query requires a composite index. Please check Firebase console for the creation link.");
            }
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              final result = snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
              print("Successfully fetched ${result.length} leave applications for $employeeId");
              return result;
            } catch (e) {
              print("Error mapping documents in getEmployeeLeaveApplications: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up employee leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }

  // Get leave applications with status filter for employee
  Stream<List<LeaveApplication>> getEmployeeLeaveApplicationsByStatus(
      String employeeId, String status) {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployeeLeaveApplicationsByStatus");
        return Stream.value([]);
      }
      
      return _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            print("Error in getEmployeeLeaveApplicationsByStatus for $employeeId with status $status: $error");
            if (error.toString().contains('index')) {
              print("This query requires a composite index on (employeeId, status, createdAt)");
            }
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
            } catch (e) {
              print("Error mapping documents in getEmployeeLeaveApplicationsByStatus: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up status filtered employee leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }

  // Get current user's leave applications
  Stream<List<LeaveApplication>> getCurrentUserLeaveApplications() async* {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user found in getCurrentUserLeaveApplications");
        yield [];
        return;
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final employeeId = userDoc.data()?['employeeId'] as String?;
      
      if (employeeId == null || employeeId.isEmpty) {
        print("User ${user.uid} has no associated employeeId or it's empty");
        yield [];
        return;
      }
      
      yield* getEmployeeLeaveApplications(employeeId);
    } catch (e) {
      print("Error in getCurrentUserLeaveApplications: $e");
      yield [];
    }
  }

  // Get leave application by ID
  Future<LeaveApplication?> getLeaveApplication(String leaveId) async {
    try {
      if (leaveId.isEmpty) {
        print("Warning: Empty leaveId provided to getLeaveApplication");
        return null;
      }
      
      final doc = await _firestore.collection('leaveApplications').doc(leaveId).get();
      if (!doc.exists) {
        print("Leave application $leaveId not found");
        return null;
      }
      return LeaveApplication.fromFirestore(doc);
    } catch (e) {
      print("Error in getLeaveApplication for $leaveId: $e");
      return null;
    }
  }

  // Create new leave application
  Future<String> createLeaveApplication({
    required String employeeId,
    required String employeeName,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    String? department,
  }) async {
    try {
      if (employeeId.isEmpty) {
        throw ArgumentError("Employee ID cannot be empty for createLeaveApplication");
      }
      
      // Using DateTime → millisecondsSinceEpoch is fine here
      final String leaveId =
          '${employeeId}_${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}';
      
      final existing = await _firestore
          .collection('leaveApplications')
          .doc(leaveId)
          .get();
          
      if (existing.exists) {
        throw Exception('A leave application already exists for these dates');
      }
      
      final data = {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'leaveType': leaveType,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'status': 'Pending',
        'reason': reason,
        'department': department,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': _auth.currentUser?.uid,
      };
      
      await _firestore
          .collection('leaveApplications')
          .doc(leaveId)
          .set(data);
          
      return leaveId;
    } catch (e) {
      print("Error in createLeaveApplication: $e");
      throw e; // Re-throw to let UI handle the error
    }
  }

  // Update leave application status
  Future<void> updateLeaveStatus(
      String leaveId, String status, {String? rejectReason}) async {
    try {
      if (leaveId.isEmpty) {
        print("Warning: Empty leaveId provided to updateLeaveStatus");
        throw ArgumentError("Leave ID cannot be empty");
      }
      
      final updateData = {
        'status': status,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      };
      
      if (status == 'Rejected' && rejectReason != null) {
        updateData['rejectReason'] = rejectReason;
      }
      
      await _firestore
          .collection('leaveApplications')
          .doc(leaveId)
          .update(updateData);
    } catch (e) {
      print("Error in updateLeaveStatus for $leaveId: $e");
      throw e; // Re-throw to let UI handle the error
    }
  }

  // Delete/cancel leave application
  Future<void> deleteLeaveApplication(String leaveId) async {
    try {
      if (leaveId.isEmpty) {
        print("Warning: Empty leaveId provided to deleteLeaveApplication");
        throw ArgumentError("Leave ID cannot be empty");
      }
      
      await _firestore.collection('leaveApplications').doc(leaveId).delete();
    } catch (e) {
      print("Error in deleteLeaveApplication for $leaveId: $e");
      throw e;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Employees
  // ────────────────────────────────────────────────────────────────────────────
  
  // Get all employees
  Stream<QuerySnapshot> getAllEmployees() {
    try {
      return _firestore
          .collection('employees')
          .snapshots()
          .handleError((error) {
            print("Error in getAllEmployees: $error");
            throw error; // Let the UI handle the error via StreamBuilder
          });
    } catch (e) {
      print("Error setting up employees stream: $e");
      return Stream<QuerySnapshot>.empty();
    }
  }
  
  // Get all employees as a List of Maps (easier to work with)
  Future<List<Map<String, dynamic>>> getAllEmployeesAsList() async {
    try {
      final snapshot = await _firestore.collection('employees').get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error in getAllEmployeesAsList: $e");
      return [];
    }
  }
  
  // Get employee by ID
  Future<DocumentSnapshot> getEmployee(String employeeId) async {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployee");
        throw ArgumentError("Employee ID cannot be empty");
      }
      
      return await _firestore.collection('employees').doc(employeeId).get();
    } catch (e) {
      print("Error in getEmployee for $employeeId: $e");
      throw e;
    }
  }
  
  // Get employee by ID and return as Map
  Future<Map<String, dynamic>?> getEmployeeById(String employeeId) async {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployeeById");
        return null;
      }
      
      final doc = await _firestore.collection('employees').doc(employeeId).get();
      if (doc.exists) {
        return doc.data();
      }
      print("Employee $employeeId not found");
      return null;
    } catch (e) {
      print("Error in getEmployeeById for $employeeId: $e");
      return null;
    }
  }
  
  // Add a new employee
  Future<void> addEmployee({
    required String id,
    required String name,
    required String department,
    String? email,
    Map<String, int>? leaveBalances,
  }) async {
    try {
      if (id.isEmpty) {
        throw ArgumentError("Employee ID cannot be empty for addEmployee");
      }
      
      final data = {
        'id': id,
        'name': name,
        'department': department,
        'email': email,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      
      // Add leave balances if provided, otherwise use defaults
      if (leaveBalances != null) {
        data['leaveBalances'] = leaveBalances;
      } else {
        data['leaveBalances'] = defaultLeaveBalances;
      }
      
      await _firestore.collection('employees').doc(id).set(data);
    } catch (e) {
      print("Error in addEmployee for $id: $e");
      throw e;
    }
  }
  
  // Update employee
  Future<void> updateEmployee({
    required String id,
    required String name,
    required String department,
    String? email,
    Map<String, int>? leaveBalances,
  }) async {
    try {
      if (id.isEmpty) {
        throw ArgumentError("Employee ID cannot be empty for updateEmployee");
      }
      
      final updateData = {
        'name': name,
        'department': department,
        'email': email,
        'updatedAt': Timestamp.now(),
      };
      
      // Only update leave balances if provided
      if (leaveBalances != null) {
        updateData['leaveBalances'] = leaveBalances;
      }
      
      await _firestore.collection('employees').doc(id).update(updateData);
    } catch (e) {
      print("Error in updateEmployee for $id: $e");
      throw e;
    }
  }
  
  // Update employee leave balances
  Future<void> updateEmployeeLeaveBalances(
      String employeeId, Map<String, int> leaveBalances) async {
    try {
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to updateEmployeeLeaveBalances");
        throw ArgumentError("Employee ID cannot be empty");
      }
      
      await _firestore.collection('employees').doc(employeeId).update({
        'leaveBalances': leaveBalances,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Error in updateEmployeeLeaveBalances for $employeeId: $e");
      throw e;
    }
  }
  
  // Get employee leave balances
  Future<Map<String, int>> getEmployeeLeaveBalances(String employeeId) async {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployeeLeaveBalances");
        return Map<String, int>.from(defaultLeaveBalances);
      }
      
      final doc = await _firestore.collection('employees').doc(employeeId).get();
      if (!doc.exists) {
        print("Employee $employeeId not found, returning default leave balances");
        return Map<String, int>.from(defaultLeaveBalances);
      }
      
      final data = doc.data();
      if (data == null || !data.containsKey('leaveBalances')) {
        print("No leave balances found for employee $employeeId, returning defaults");
        return Map<String, int>.from(defaultLeaveBalances);
      }
      
      return Map<String, int>.from(data['leaveBalances']);
    } catch (e) {
      print("Error in getEmployeeLeaveBalances for $employeeId: $e");
      return Map<String, int>.from(defaultLeaveBalances);
    }
  }
  
  // Delete employee
  Future<void> deleteEmployee(String employeeId) async {
    try {
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to deleteEmployee");
        throw ArgumentError("Employee ID cannot be empty");
      }
      
      // First delete the employee
      await _firestore.collection('employees').doc(employeeId).delete();
      
      // Then delete all leave applications for this employee
      final leaveApplications = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .get();
          
      // Use a batch to delete multiple documents efficiently
      if (leaveApplications.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in leaveApplications.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print("Error in deleteEmployee for $employeeId: $e");
      throw e;
    }
  }

  Future<void> createOrUpdateEmployee(
      String employeeId, Map<String, dynamic> data) async {
    try {
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to createOrUpdateEmployee");
        throw ArgumentError("Employee ID cannot be empty");
      }
      
      await _firestore
          .collection('employees')
          .doc(employeeId)
          .set({
        ...data,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error in createOrUpdateEmployee for $employeeId: $e");
      throw e;
    }
  }

  Future<DocumentSnapshot?> getEmployeeByUserId(String userId) async {
    try {
      if (userId.isEmpty) {
        print("Warning: Empty userId provided to getEmployeeByUserId");
        return null;
      }
      
      final qs = await _firestore
          .collection('employees')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      return qs.docs.isEmpty ? null : qs.docs.first;
    } catch (e) {
      print("Error in getEmployeeByUserId for $userId: $e");
      return null;
    }
  }
  
  // Get employees by department
  Future<List<Map<String, dynamic>>> getEmployeesByDepartment(String department) async {
    try {
      if (department.isEmpty) {
        print("Warning: Empty department provided to getEmployeesByDepartment");
        return [];
      }
      
      final snapshot = await _firestore
          .collection('employees')
          .where('department', isEqualTo: department)
          .get();
      
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error in getEmployeesByDepartment for $department: $e");
      return [];
    }
  }

  // Get employees with pending leave applications
  Future<List<String>> getEmployeesWithPendingLeaves() async {
    try {
      final snapshot = await _firestore
          .collection('leaveApplications')
          .where('status', isEqualTo: 'Pending')
          .get();
      
      // Extract unique employee IDs
      final Set<String> employeeIds = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final employeeId = data['employeeId'] as String?;
        if (employeeId != null && employeeId.isNotEmpty) {
          employeeIds.add(employeeId);
        }
      }
      
      return employeeIds.toList();
    } catch (e) {
      print("Error in getEmployeesWithPendingLeaves: $e");
      return [];
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Users
  // ────────────────────────────────────────────────────────────────────────────
  Future<DocumentSnapshot> getUser(String userId) async {
    try {
      if (userId.isEmpty) {
        print("Warning: Empty userId provided to getUser");
        throw ArgumentError("User ID cannot be empty");
      }
      
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      print("Error in getUser for $userId: $e");
      throw e;
    }
  }

  Future<void> createOrUpdateUser(
      String userId, Map<String, dynamic> data) async {
    try {
      if (userId.isEmpty) {
        print("Warning: Empty userId provided to createOrUpdateUser");
        throw ArgumentError("User ID cannot be empty");
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        ...data,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error in createOrUpdateUser for $userId: $e");
      throw e;
    }
  }

  Future<QuerySnapshot> getAllHRUsers() async {
    try {
      return await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'HR_ADMIN')
          .get();
    } catch (e) {
      print("Error in getAllHRUsers: $e");
      throw e;
    }
  }
  
  // Get current user details
  Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user found in getCurrentUserDetails");
        return null;
      }
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print("User document not found for ${user.uid}");
        return null;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        return null;
      }
      
      // If user has employeeId, get additional employee details
      final employeeId = userData['employeeId'] as String?;
      if (employeeId != null && employeeId.isNotEmpty) {
        final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
        if (employeeDoc.exists) {
          final employeeData = employeeDoc.data();
          if (employeeData != null) {
            // Merge employee data with user data
            return {
              ...userData,
              ...employeeData,
            };
          }
        }
      }
      
      return userData;
    } catch (e) {
      print("Error in getCurrentUserDetails: $e");
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Storage
  // ────────────────────────────────────────────────────────────────────────────
  Future<String> uploadErrorScreenshot(
      Uint8List screenshotBytes, String errorId) async {
    try {
      if (errorId.isEmpty) {
        print("Warning: Empty errorId provided to uploadErrorScreenshot");
        throw ArgumentError("Error ID cannot be empty");
      }
      
      final ref = _storage.ref('error_screenshots/$errorId.png');
      await ref.putData(screenshotBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error in uploadErrorScreenshot for $errorId: $e");
      throw e;
    }
  }

  Future<String> uploadFile(Uint8List fileBytes, String path) async {
    try {
      if (path.isEmpty) {
        print("Warning: Empty path provided to uploadFile");
        throw ArgumentError("File path cannot be empty");
      }
      
      final ref = _storage.ref(path);
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error in uploadFile for $path: $e");
      throw e;
    }
  }
  
  // Upload supporting document for leave application
  Future<String> uploadLeaveDocument(
      Uint8List documentBytes, String leaveId, String fileName) async {
    try {
      if (leaveId.isEmpty) {
        print("Warning: Empty leaveId provided to uploadLeaveDocument");
        throw ArgumentError("Leave ID cannot be empty");
      }
      
      if (fileName.isEmpty) {
        print("Warning: Empty fileName provided to uploadLeaveDocument");
        throw ArgumentError("File name cannot be empty");
      }
      
      final path = 'leave_documents/$leaveId/$fileName';
      final ref = _storage.ref(path);
      await ref.putData(documentBytes);
      final downloadUrl = await ref.getDownloadURL();
      
      // Update leave application with document URL
      await _firestore.collection('leaveApplications').doc(leaveId).update({
        'documentUrl': downloadUrl,
        'documentName': fileName,
        'updatedAt': Timestamp.now(),
      });
      
      return downloadUrl;
    } catch (e) {
      print("Error in uploadLeaveDocument for $leaveId: $e");
      throw e;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Batch Import
  // ────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> batchImportEmployees(
      List<Map<String, dynamic>> employees) async {
    try {
      final batch = _firestore.batch();
      int successCount = 0;
      for (var emp in employees) {
        final id = emp['id'];
        if (id == null || id.toString().isEmpty) continue;
        final docRef = _firestore.collection('employees').doc(id);
        batch.set(docRef, {
          ...emp,
          'updatedAt': Timestamp.now(),
          if (!emp.containsKey('createdAt')) 'createdAt': Timestamp.now(),
          if (!emp.containsKey('leaveBalances')) 'leaveBalances': defaultLeaveBalances,
        }, SetOptions(merge: true));
        successCount++;
      }
      await batch.commit();
      return {
        'success': true,
        'count': successCount,
      };
    } catch (e) {
      print("Error in batchImportEmployees: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> batchImportLeaveApplications(
      List<Map<String, dynamic>> applications) async {
    try {
      final batch = _firestore.batch();
      int successCount = 0, duplicateCount = 0;
      for (var app in applications) {
        final employeeId = app['employeeId'] as String?;
        final startTs = app['startDate'] as Timestamp?;
        final endTs = app['endDate'] as Timestamp?;
        if (employeeId == null || employeeId.isEmpty || startTs == null || endTs == null) continue;
        // ← FIX: convert Timestamp → DateTime → millis
        final startMs = startTs.toDate().millisecondsSinceEpoch;
        final endMs = endTs.toDate().millisecondsSinceEpoch;
        final leaveId = '${employeeId}_${startMs}_${endMs}';
        final existing = await _firestore
            .collection('leaveApplications')
            .doc(leaveId)
            .get();
        if (existing.exists) {
          duplicateCount++;
          continue;
        }
        batch.set(
          _firestore.collection('leaveApplications').doc(leaveId),
          {
            ...app,
            'createdAt': app.containsKey('createdAt')
                ? app['createdAt']
                : Timestamp.now(),
            'updatedAt': Timestamp.now(),
          },
        );
        successCount++;
      }
      await batch.commit();
      return {
        'success': true,
        'count': successCount,
        'duplicates': duplicateCount,
      };
    } catch (e) {
      print("Error in batchImportLeaveApplications: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Analytics
  // ────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLeaveStatistics() async {
    try {
      final snap = await _firestore.collection('leaveApplications').get();
      int pending = 0, approved = 0, rejected = 0, cancelled = 0;
      int annual = 0, medical = 0, emergency = 0, other = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final type = data['leaveType'] as String? ?? '';
        
        // Count by status
        if (status == 'Pending') pending++;
        else if (status == 'Approved') approved++;
        else if (status == 'Rejected') rejected++;
        else if (status == 'Cancelled') cancelled++;
        
        // Count by type
        if (type.toLowerCase().contains('annual')) annual++;
        else if (type.toLowerCase().contains('medical')) medical++;
        else if (type.toLowerCase().contains('emergency')) emergency++;
        else other++;
      }
      
      return {
        'total': snap.docs.length,
        'status': {
          'pending': pending,
          'approved': approved,
          'rejected': rejected,
          'cancelled': cancelled,
        },
        'type': {
          'annual': annual,
          'medical': medical,
          'emergency': emergency,
          'other': other,
        },
      };
    } catch (e) {
      print("Error in getLeaveStatistics: $e");
      return {
        'total': 0,
        'status': {
          'pending': 0, 
          'approved': 0, 
          'rejected': 0,
          'cancelled': 0,
        },
        'type': {
          'annual': 0, 
          'medical': 0, 
          'emergency': 0,
          'other': 0,
        },
      };
    }
  }

  Future<Map<String, dynamic>> getEmployeeLeaveStatistics(String employeeId) async {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to getEmployeeLeaveStatistics");
        return {
          'total': 0,
          'status': {
            'pending': 0, 
            'approved': 0, 
            'rejected': 0,
            'cancelled': 0,
          },
          'type': {
            'annual': 0, 
            'medical': 0, 
            'emergency': 0,
            'other': 0,
          },
          'balance': defaultLeaveBalances,
        };
      }
      
      // Get leave applications
      final snap = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .get();
      
      int pending = 0, approved = 0, rejected = 0, cancelled = 0;
      int annual = 0, medical = 0, emergency = 0, other = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final type = data['leaveType'] as String? ?? '';
        
        // Count by status
        if (status == 'Pending') pending++;
        else if (status == 'Approved') approved++;
        else if (status == 'Rejected') rejected++;
        else if (status == 'Cancelled') cancelled++;
        
        // Count by type
        if (type.toLowerCase().contains('annual')) annual++;
        else if (type.toLowerCase().contains('medical')) medical++;
        else if (type.toLowerCase().contains('emergency')) emergency++;
        else other++;
      }
      
      // Get employee leave balances
      final leaveBalances = await getEmployeeLeaveBalances(employeeId);
      
      return {
        'total': snap.docs.length,
        'status': {
          'pending': pending,
          'approved': approved,
          'rejected': rejected,
          'cancelled': cancelled,
        },
        'type': {
          'annual': annual,
          'medical': medical,
          'emergency': emergency,
          'other': other,
        },
        'balance': leaveBalances,
      };
    } catch (e) {
      print("Error in getEmployeeLeaveStatistics for $employeeId: $e");
      return {
        'total': 0,
        'status': {
          'pending': 0, 
          'approved': 0, 
          'rejected': 0,
          'cancelled': 0,
        },
        'type': {
          'annual': 0, 
          'medical': 0, 
          'emergency': 0,
          'other': 0,
        },
        'balance': defaultLeaveBalances,
      };
    }
  }
  
  // Calculate remaining leave days for an employee
  Future<Map<String, int>> calculateRemainingLeaveDays(String employeeId) async {
    try {
      // Add check for empty employee ID
      if (employeeId.isEmpty) {
        print("Warning: Empty employeeId provided to calculateRemainingLeaveDays");
        return Map<String, int>.from(defaultLeaveBalances);
      }
      
      // Get employee leave balances
      final leaveBalances = await getEmployeeLeaveBalances(employeeId);
      
      // Get approved and pending leave applications for this year
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);
      
      final approvedLeaves = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'Approved')
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
          .get();
      
      final pendingLeaves = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'Pending')
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
          .get();
      
      // Calculate used leave days by type
      int usedAnnual = 0, usedMedical = 0, usedEmergency = 0;
      
      // Helper function to count leave days
      void countLeaveDays(QuerySnapshot snap) {
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['leaveType'] as String? ?? '';
          final startDate = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final endDate = (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          
          // Calculate days (inclusive)
          final days = endDate.difference(startDate).inDays + 1;
          
          // Add to appropriate counter
          if (type.toLowerCase().contains('annual')) {
            usedAnnual += days;
          } else if (type.toLowerCase().contains('medical')) {
            usedMedical += days;
          } else if (type.toLowerCase().contains('emergency')) {
            usedEmergency += days;
          }
        }
      }
      
      // Count approved and pending leaves
      countLeaveDays(approvedLeaves);
      countLeaveDays(pendingLeaves);
      
      // Calculate remaining days
      final annualBalance = leaveBalances['annual'] ?? defaultLeaveBalances['annual'] ?? 0;
      final medicalBalance = leaveBalances['medical'] ?? defaultLeaveBalances['medical'] ?? 0;
      final emergencyBalance = leaveBalances['emergency'] ?? defaultLeaveBalances['emergency'] ?? 0;
      
      final remaining = {
        'annual': annualBalance - usedAnnual,
        'medical': medicalBalance - usedMedical,
        'emergency': emergencyBalance - usedEmergency,
      };
      
      return remaining;
    } catch (e) {
      print("Error in calculateRemainingLeaveDays for $employeeId: $e");
      return defaultLeaveBalances;
    }
  }
  
  // Get department leave statistics
  Future<Map<String, dynamic>> getDepartmentLeaveStatistics(String department) async {
    try {
      if (department.isEmpty) {
        print("Warning: Empty department provided to getDepartmentLeaveStatistics");
        return {
          'total': 0,
          'status': {'pending': 0, 'approved': 0, 'rejected': 0},
          'type': {'annual': 0, 'medical': 0, 'emergency': 0},
        };
      }
      
      final snap = await _firestore
          .collection('leaveApplications')
          .where('department', isEqualTo: department)
          .get();
      
      int pending = 0, approved = 0, rejected = 0;
      int annual = 0, medical = 0, emergency = 0;
      
      for (var doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final type = data['leaveType'] as String? ?? '';
        
        if (status == 'Pending') pending++;
        else if (status == 'Approved') approved++;
        else if (status == 'Rejected') rejected++;
        
        if (type.toLowerCase().contains('annual')) annual++;
        else if (type.toLowerCase().contains('medical')) medical++;
        else if (type.toLowerCase().contains('emergency')) emergency++;
      }
      
      return {
        'total': snap.docs.length,
        'status': {
          'pending': pending,
          'approved': approved,
          'rejected': rejected,
        },
        'type': {
          'annual': annual,
          'medical': medical,
          'emergency': emergency,
        },
      };
    } catch (e) {
      print("Error in getDepartmentLeaveStatistics for $department: $e");
      return {
        'total': 0,
        'status': {'pending': 0, 'approved': 0, 'rejected': 0},
        'type': {'annual': 0, 'medical': 0, 'emergency': 0},
      };
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Search and Filtering
  // ────────────────────────────────────────────────────────────────────────────
  
  // Get filtered leave applications by status
  Stream<List<LeaveApplication>> getLeaveApplicationsByStatus(String status) {
    try {
      if (status.isEmpty) {
        print("Warning: Empty status provided to getLeaveApplicationsByStatus");
        return Stream.value([]);
      }
      
      return _firestore
          .collection('leaveApplications')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            print("Error in getLeaveApplicationsByStatus for $status: $error");
            if (error.toString().contains('index')) {
              print("This query requires a composite index on (status, createdAt)");
            }
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
            } catch (e) {
              print("Error mapping documents in getLeaveApplicationsByStatus: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up status filtered leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }
  
  // Get leave applications by date range
  Stream<List<LeaveApplication>> getLeaveApplicationsByDateRange(
      DateTime startDate, DateTime endDate) {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);
      
      return _firestore
          .collection('leaveApplications')
          .where('startDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('startDate', isLessThanOrEqualTo: endTimestamp)
          .orderBy('startDate')
          .snapshots()
          .handleError((error) {
            print("Error in getLeaveApplicationsByDateRange: $error");
            if (error.toString().contains('index')) {
              print("This query requires a composite index on startDate");
            }
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
            } catch (e) {
              print("Error mapping documents in getLeaveApplicationsByDateRange: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up date range filtered leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }
  
  // Get leave applications by type
  Stream<List<LeaveApplication>> getLeaveApplicationsByType(String leaveType) {
    try {
      if (leaveType.isEmpty) {
        print("Warning: Empty leaveType provided to getLeaveApplicationsByType");
        return Stream.value([]);
      }
      
      return _firestore
          .collection('leaveApplications')
          .where('leaveType', isEqualTo: leaveType)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .handleError((error) {
            print("Error in getLeaveApplicationsByType for $leaveType: $error");
            if (error.toString().contains('index')) {
              print("This query requires a composite index on (leaveType, createdAt)");
            }
            return Stream.value([]);
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => LeaveApplication.fromFirestore(doc))
                  .toList();
            } catch (e) {
              print("Error mapping documents in getLeaveApplicationsByType: $e");
              return <LeaveApplication>[];
            }
          });
    } catch (e) {
      print("Error setting up type filtered leave applications stream: $e");
      return Stream<List<LeaveApplication>>.empty();
    }
  }
  
  // Search employees by name, ID or department
  Future<List<DocumentSnapshot>> searchEmployees(String query) async {
    try {
      query = query.toLowerCase();
      
      // Since Firestore doesn't support case-insensitive search directly,
      // we need to fetch all employees and filter client-side
      final snapshot = await _firestore.collection('employees').get();
      
      return snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] as String? ?? '').toLowerCase();
        final id = (data['id'] as String? ?? '').toLowerCase();
        final department = (data['department'] as String? ?? '').toLowerCase();
        
        return name.contains(query) || 
               id.contains(query) || 
               department.contains(query);
      }).toList();
    } catch (e) {
      print("Error in searchEmployees for '$query': $e");
      return [];
    }
  }
  
  // Search leave applications
  Future<List<LeaveApplication>> searchLeaveApplications(String query) async {
    try {
      query = query.toLowerCase();
      
      // Fetch all leave applications (could be optimized further if needed)
      final snapshot = await _firestore
          .collection('leaveApplications')
          .orderBy('createdAt', descending: true)
          .get();
      
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final employeeName = (data['employeeName'] as String? ?? '').toLowerCase();
        final employeeId = (data['employeeId'] as String? ?? '').toLowerCase();
        final leaveType = (data['leaveType'] as String? ?? '').toLowerCase();
        final status = (data['status'] as String? ?? '').toLowerCase();
        final reason = (data['reason'] as String? ?? '').toLowerCase();
        final department = (data['department'] as String? ?? '').toLowerCase();
        
        return employeeName.contains(query) || 
               employeeId.contains(query) || 
               leaveType.contains(query) ||
               status.contains(query) ||
               reason.contains(query) ||
               department.contains(query);
      }).toList();
      
      return matchingDocs
          .map((doc) => LeaveApplication.fromFirestore(doc))
          .toList();
    } catch (e) {
      print("Error in searchLeaveApplications for '$query': $e");
      return [];
    }
  }
}