import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Login with email and password
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Check if user is HR admin
  Future<bool> isHRAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return (userDoc.data()?['userType'] == 'HR_ADMIN');
  }

  // Get user type
  Future<String> getUserType() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['userType'] ?? 'EMPLOYEE';
  }

  /// Get current user details — with automatic employee linking
  Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No authenticated user found");
        return null;
      }

      // 1) Fetch or create the minimal user doc
      final userRef = _firestore.collection('users').doc(user.uid);
      final userSnap = await userRef.get();
      Map<String, dynamic> userMap;

      if (userSnap.exists) {
        userMap = userSnap.data()!;
      } else {
        userMap = {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'Employee',
          'userType': 'EMPLOYEE',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        };
        await userRef.set(userMap);
        print("Created new user document for ${user.uid}");
      }

      // Always include these
      userMap['uid'] = user.uid;
      userMap['email'] = user.email;

      // 2) Try to auto-link by email if no employeeId
      String? employeeId = userMap['employeeId'] as String?;

      if (employeeId == null || employeeId.isEmpty) {
        print("No valid employeeId — attempting to find by email ${user.email}");
        final empQuery = await _firestore
            .collection('employees')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (empQuery.docs.isNotEmpty) {
          final empData = empQuery.docs.first.data();
          final foundId = empData['id'] as String?;
          if (foundId != null && foundId.isNotEmpty) {
            employeeId = foundId;
            print("Found matching employee record: $employeeId");

            // Update user doc
            await userRef.update({
              'employeeId': employeeId,
              'name': empData['name'] ?? userMap['name'],
              'updatedAt': Timestamp.now(),
            });

            // Back-link in employees
            await _firestore.collection('employees').doc(employeeId).update({
              'userId': user.uid,
              'updatedAt': Timestamp.now(),
            });

            // Merge into userMap
            userMap['employeeId'] = employeeId;
            userMap['name'] = empData['name'] ?? userMap['name'];
          }
        } else {
          print("No employee found for ${user.email}");
        }
      }

      // 3) If we now have an employeeId, fetch full employee details
      if (employeeId != null && employeeId.isNotEmpty) {
        print("Fetching employee doc for ID: $employeeId");
        final empDoc = await _firestore.collection('employees').doc(employeeId).get();
        if (empDoc.exists) {
          final empMap = empDoc.data()!;
          empMap['id'] = empMap['id'] ?? employeeId;

          // Ensure back-link
          if (empMap['userId'] == null || empMap['userId'].toString().isEmpty) {
            await _firestore.collection('employees').doc(employeeId).update({
              'userId': user.uid,
              'updatedAt': Timestamp.now(),
            });
            empMap['userId'] = user.uid;
          }

          // Merge
          userMap.addAll(empMap);
        } else {
          print("Employee document not found for $employeeId");
        }
      } else {
        print("User ${user.uid} has no valid employeeId after auto-link");
      }

      // Truncate log output for large maps
      final summary = userMap.toString();
      print("Returning user details: ${summary.substring(0, min(100, summary.length))}...");
      return userMap;
    } catch (e) {
      print("Error in getCurrentUserDetails: $e");
      return null;
    }
  }

  // The rest of your existing methods below…

  Future<UserCredential> createUser(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'userType': 'EMPLOYEE',
      'createdAt': Timestamp.now(),
    });
    return cred;
  }

  Future<UserCredential> createHRAdmin(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'name': name,
      'userType': 'HR_ADMIN',
      'department': 'HR',
      'createdAt': Timestamp.now(),
    });
    return cred;
  }

  Future<UserCredential> createEmployeeUser(
    String email,
    String password,
    String name,
    String employeeId,
    String department,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // write both /users and /employees as you had…
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'name': name,
      'userType': 'EMPLOYEE',
      'employeeId': employeeId,
      'createdAt': Timestamp.now(),
    });
    await _firestore.collection('employees').doc(employeeId).set({
      'id': employeeId,
      'name': name,
      'department': department,
      'email': email,
      'userId': cred.user!.uid,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    return cred;
  }

  Future<void> updateUserProfile(String name, String? department) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await _firestore.collection('users').doc(user.uid).update({
      'name': name,
      'updatedAt': Timestamp.now(),
    });
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final empId = userDoc.data()?['employeeId'];
    if (empId != null && department != null) {
      await _firestore.collection('employees').doc(empId).update({
        'name': name,
        'department': department,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final email = user.email!;
    final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }
}