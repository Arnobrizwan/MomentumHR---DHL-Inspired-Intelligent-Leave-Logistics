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
  Stream<List<LeaveApplication>> getAllLeaveApplications() {
    return _firestore
        .collection('leaveApplications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LeaveApplication.fromFirestore(doc)).toList());
  }

  // Get leave applications for specific employee
  Stream<List<LeaveApplication>> getEmployeeLeaveApplications(String employeeId) {
    return _firestore
        .collection('leaveApplications')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LeaveApplication.fromFirestore(doc)).toList());
  }

  // Get current user's leave applications
  Stream<List<LeaveApplication>> getCurrentUserLeaveApplications() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final employeeId = userDoc.data()?['employeeId'] as String?;
    if (employeeId == null) {
      yield [];
      return;
    }

    yield* getEmployeeLeaveApplications(employeeId);
  }

  // Get leave application by ID
  Future<LeaveApplication?> getLeaveApplication(String leaveId) async {
    final doc =
        await _firestore.collection('leaveApplications').doc(leaveId).get();
    if (!doc.exists) return null;
    return LeaveApplication.fromFirestore(doc);
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
  }

  // Update leave application status
  Future<void> updateLeaveStatus(
      String leaveId, String status, {String? rejectReason}) async {
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
  }

  // Delete/cancel leave application
  Future<void> deleteLeaveApplication(String leaveId) =>
      _firestore.collection('leaveApplications').doc(leaveId).delete();

  // ────────────────────────────────────────────────────────────────────────────
  // Employees
  // ────────────────────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getAllEmployees() =>
      _firestore.collection('employees').snapshots();

  Future<DocumentSnapshot> getEmployee(String employeeId) =>
      _firestore.collection('employees').doc(employeeId).get();

  Future<void> createOrUpdateEmployee(
          String employeeId, Map<String, dynamic> data) async =>
      _firestore
          .collection('employees')
          .doc(employeeId)
          .set({
            ...data,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));

  Future<DocumentSnapshot?> getEmployeeByUserId(String userId) async {
    final qs = await _firestore
        .collection('employees')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return qs.docs.isEmpty ? null : qs.docs.first;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Users
  // ────────────────────────────────────────────────────────────────────────────

  Future<DocumentSnapshot> getUser(String userId) =>
      _firestore.collection('users').doc(userId).get();

  Future<void> createOrUpdateUser(
          String userId, Map<String, dynamic> data) async =>
      _firestore
          .collection('users')
          .doc(userId)
          .set({
            ...data,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));

  Future<QuerySnapshot> getAllHRUsers() => _firestore
      .collection('users')
      .where('userType', isEqualTo: 'HR_ADMIN')
      .get();

  // ────────────────────────────────────────────────────────────────────────────
  // Storage
  // ────────────────────────────────────────────────────────────────────────────

  Future<String> uploadErrorScreenshot(
          Uint8List screenshotBytes, String errorId) async {
    final ref = _storage.ref('error_screenshots/$errorId.png');
    await ref.putData(screenshotBytes);
    return ref.getDownloadURL();
  }

  Future<String> uploadFile(Uint8List fileBytes, String path) async {
    final ref = _storage.ref(path);
    await ref.putData(fileBytes);
    return ref.getDownloadURL();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Batch Import
  // ────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> batchImportEmployees(
      List<Map<String, dynamic>> employees) async {
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
  }

  Future<Map<String, dynamic>> batchImportLeaveApplications(
      List<Map<String, dynamic>> applications) async {
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
      final leaveId = '${employeeId}_$startMs\_$endMs';

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
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Analytics
  // ────────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLeaveStatistics() async {
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
  }

  Future<Map<String, dynamic>> getEmployeeLeaveStatistics(
      String employeeId) async {
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
  }
}