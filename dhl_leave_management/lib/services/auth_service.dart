import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }
  
  // Check if user is HR admin
  Future<bool> isHRAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;
      
      final userType = userDoc.data()?['userType'];
      return userType == 'HR_ADMIN';
    } catch (e) {
      return false;
    }
  }
  
  // Get user type (HR_ADMIN or EMPLOYEE)
  Future<String> getUserType() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '';
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return '';
      
      return userDoc.data()?['userType'] ?? 'EMPLOYEE';
    } catch (e) {
      return '';
    }
  }
  
  // Get current user details
  Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;
      
      final userMap = userDoc.data();
      userMap?['uid'] = user.uid;
      userMap?['email'] = user.email;
      
      // If user has employee ID, fetch employee details
      if (userMap?['employeeId'] != null) {
        final employeeDoc = await _firestore
            .collection('employees')
            .doc(userMap?['employeeId'])
            .get();
            
        if (employeeDoc.exists) {
          final employeeMap = employeeDoc.data();
          // Merge employee details with user details
          userMap?.addAll(employeeMap ?? {});
        }
      }
      
      return userMap;
    } catch (e) {
      return null;
    }
  }
  
  // Create a new user
  Future<UserCredential> createUser(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'userType': 'EMPLOYEE', // Default to employee
        'createdAt': Timestamp.now(),
      });
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Create an HR admin user
  Future<UserCredential> createHRAdmin(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create HR admin document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'userType': 'HR_ADMIN',
        'createdAt': Timestamp.now(),
        'department': 'HR',
      });
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Create an employee user and link to employee record
  Future<UserCredential> createEmployeeUser(
    String email,
    String password,
    String name,
    String employeeId,
    String department,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'userType': 'EMPLOYEE',
        'employeeId': employeeId,
        'createdAt': Timestamp.now(),
      });
      
      // Update employee record with user ID
      await _firestore.collection('employees').doc(employeeId).set({
        'id': employeeId,
        'name': name,
        'department': department,
        'email': email,
        'userId': userCredential.user!.uid,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(String name, String? department) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Update user document
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'updatedAt': Timestamp.now(),
      });
      
      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final employeeId = userDoc.data()?['employeeId'];
      
      // If user has employee ID and department is provided, update employee record
      if (employeeId != null && department != null) {
        await _firestore.collection('employees').doc(employeeId).update({
          'name': name,
          'department': department,
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
  
  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Get user email
      final email = user.email;
      if (email == null) throw Exception('User email not found');
      
      // Create credential with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      
      // Re-authenticate user
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }
}