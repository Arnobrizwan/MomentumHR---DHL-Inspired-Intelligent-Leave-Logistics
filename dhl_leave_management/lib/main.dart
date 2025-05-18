import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:dhl_leave_management/config/firebase_options.dart';
import 'package:dhl_leave_management/config/theme.dart';
import 'package:dhl_leave_management/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DHL Leave Management',
      theme: DHLTheme.lightTheme,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}