import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:test_cv/screens/company_login.dart';
import 'package:test_cv/screens/company_register.dart';
import 'package:test_cv/screens/landing_screen.dart';
import 'package:test_cv/screens/student_login_screen.dart';
import 'package:test_cv/screens/student_register.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if Firebase is already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    Firebase.app(); // if already initialized, use that one
  }

  // Optional: Set database URL directly if needed
  FirebaseDatabase.instance.databaseURL =
      'https://cvsync-2c3a8-default-rtdb.asia-southeast1.firebasedatabase.app';

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LandingScreen(),
      routes: {
        '/studentLogin': (context) => StudentLoginScreen(),
        '/studentRegister': (context) => StudentRegister(),
        '/companyLogin': (context) => CompanyLoginScreen(),
        '/companyRegister': (context) => CompanyRegistrationScreen(),
        // '/cv_form': (context) => CvFormScreen(), // Add route for CV form
      },
    );
  }
}
