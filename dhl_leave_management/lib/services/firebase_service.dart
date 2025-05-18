import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dhl_leave_management/models/leave_application.dart';
import 'dart:typed_data';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ────────────────────────────────────────────────────────────────────────────
  // Leave Applications
  // ────────────────────────────────────────────────────────────────────────────
  
  // Get all leave applications
  // Required index: createdAt DESC
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
  // Required index: composite (employeeId, createdAt DESC)
  Stream<List<LeaveApplication>> getEmployeeLeaveApplications(String employeeId) {
    try {
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
      
      if (employeeId == null) {
        print("User ${user.uid} has no associated employeeId");
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
  }) async {
    try {
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
  
  // Get employee by ID
  Future<DocumentSnapshot> getEmployee(String employeeId) async {
    try {
      return await _firestore.collection('employees').doc(employeeId).get();
    } catch (e) {
      print("Error in getEmployee for $employeeId: $e");
      throw e;
    }
  }
  
  // Get employee by ID and return as Map
  Future<Map<String, dynamic>?> getEmployeeById(String employeeId) async {
    try {
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
  }) async {
    try {
      await _firestore.collection('employees').doc(id).set({
        'id': id,
        'name': name,
        'department': department,
        'email': email,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
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
  }) async {
    try {
      await _firestore.collection('employees').doc(id).update({
        'name': name,
        'department': department,
        'email': email,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print("Error in updateEmployee for $id: $e");
      throw e;
    }
  }
  
  // Delete employee
  Future<void> deleteEmployee(String employeeId) async {
    try {
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

  // ────────────────────────────────────────────────────────────────────────────
  // Users
  // ────────────────────────────────────────────────────────────────────────────
  Future<DocumentSnapshot> getUser(String userId) async {
    try {
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      print("Error in getUser for $userId: $e");
      throw e;
    }
  }

  Future<void> createOrUpdateUser(
      String userId, Map<String, dynamic> data) async {
    try {
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

  // ────────────────────────────────────────────────────────────────────────────
  // Storage
  // ────────────────────────────────────────────────────────────────────────────
  Future<String> uploadErrorScreenshot(
      Uint8List screenshotBytes, String errorId) async {
    try {
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
      final ref = _storage.ref(path);
      await ref.putData(fileBytes);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error in uploadFile for $path: $e");
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
        if (id == null) continue;
        final docRef = _firestore.collection('employees').doc(id);
        batch.set(docRef, {
          ...emp,
          'updatedAt': Timestamp.now(),
          if (!emp.containsKey('createdAt')) 'createdAt': Timestamp.now(),
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
        if (employeeId == null || startTs == null || endTs == null) continue;
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
      int pending = 0, approved = 0, rejected = 0;
      int annual = 0, medical = 0, emergency = 0;
      for (var doc in snap.docs) {
        final s = doc['status'] as String? ?? '';
        final t = doc['leaveType'] as String? ?? '';
        if (s == 'Pending') pending++;
        if (s == 'Approved') approved++;
        if (s == 'Rejected') rejected++;
        if (t.contains('Annual')) annual++;
        if (t.contains('Medical')) medical++;
        if (t.contains('Emergency')) emergency++;
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
      print("Error in getLeaveStatistics: $e");
      return {
        'total': 0,
        'status': {'pending': 0, 'approved': 0, 'rejected': 0},
        'type': {'annual': 0, 'medical': 0, 'emergency': 0},
      };
    }
  }

  Future<Map<String, dynamic>> getEmployeeLeaveStatistics(
      String employeeId) async {
    try {
      final snap = await _firestore
          .collection('leaveApplications')
          .where('employeeId', isEqualTo: employeeId)
          .get();
      int pending = 0, approved = 0, rejected = 0;
      int annual = 0, medical = 0, emergency = 0;
      for (var doc in snap.docs) {
        final s = doc['status'] as String? ?? '';
        final t = doc['leaveType'] as String? ?? '';
        if (s == 'Pending') pending++;
        if (s == 'Approved') approved++;
        if (s == 'Rejected') rejected++;
        if (t.contains('Annual')) annual++;
        if (t.contains('Medical')) medical++;
        if (t.contains('Emergency')) emergency++;
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
      print("Error in getEmployeeLeaveStatistics for $employeeId: $e");
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
  // Required index: composite (status, createdAt DESC)
  Stream<List<LeaveApplication>> getLeaveApplicationsByStatus(String status) {
    try {
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
  // Required index: composite (startDate ASC)
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
}