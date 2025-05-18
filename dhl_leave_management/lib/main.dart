import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dhl_leave_management/config/firebase_options.dart';
import 'package:dhl_leave_management/config/theme.dart';
import 'package:dhl_leave_management/screens/login_screen.dart';
import 'package:dhl_leave_management/screens/dashboard_screen.dart';
import 'package:dhl_leave_management/screens/employee_dashboard_screen.dart';
import 'package:dhl_leave_management/screens/profile_screen.dart';
import 'package:dhl_leave_management/screens/import_screen.dart';
import 'package:dhl_leave_management/screens/leave_application_form.dart';
import 'package:dhl_leave_management/screens/leave_detail_screen.dart';
import 'package:dhl_leave_management/screens/chatbot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Determine initial route based on authentication state
  final initialRoute = await AppRouter.getInitialRoute();
  
  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  
  const MyApp({
    super.key,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DHL Leave Management',
      theme: DHLTheme.lightTheme,
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}

// App Router functionality integrated into main.dart
class AppRouter {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Named routes
  static const String login = '/login';
  static const String hrDashboard = '/hr/dashboard';
  static const String employeeDashboard = '/employee/dashboard';
  static const String profile = '/profile';
  static const String importExcel = '/hr/import';
  static const String applyLeave = '/leave/apply';
  static const String leaveDetail = '/leave/detail';
  static const String chatbot = '/chatbot';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
        
      case hrDashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
        
      case employeeDashboard:
        return MaterialPageRoute(builder: (_) => const EmployeeDashboardScreen());
        
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
        
      case importExcel:
        return MaterialPageRoute(builder: (_) => const ImportScreen());
        
      case applyLeave:
        final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => LeaveApplicationForm(
            employeeId: args?['employeeId'],
            employeeName: args?['employeeName'],
          ),
        );
        
      case leaveDetail:
        final String leaveId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => LeaveDetailScreen(leaveId: leaveId),
        );
        
      case chatbot:
        return MaterialPageRoute(builder: (_) => const ChatbotScreen());
        
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
  
  // Initial route determination based on authentication state
  static Future<String> getInitialRoute() async {
    // Check if user is logged in
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return login;
    }
    
    try {
      // Check user type
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        return login;
      }
      
      final userType = userDoc.data()?['userType'];
      if (userType == 'HR_ADMIN') {
        return hrDashboard;
      } else {
        return employeeDashboard;
      }
    } catch (e) {
      // If there's any error, default to login
      return login;
    }
  }
  
  // Helper method to navigate based on user type
  static Future<void> navigateBasedOnUserType(BuildContext context) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushReplacementNamed(login);
      return;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        Navigator.of(context).pushReplacementNamed(login);
        return;
      }
      
      final userType = userDoc.data()?['userType'];
      if (userType == 'HR_ADMIN') {
        Navigator.of(context).pushReplacementNamed(hrDashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(employeeDashboard);
      }
    } catch (e) {
      Navigator.of(context).pushReplacementNamed(login);
    }
  }
}