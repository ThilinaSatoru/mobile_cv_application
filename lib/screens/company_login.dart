import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'company_home.dart';

class CompanyLoginScreen extends StatefulWidget {
  @override
  _CompanyLoginScreenState createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _passwordController =
      TextEditingController(); // Added password controller
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("companies");

  void _loginCompany() async {
    String name = _companyNameController.text.trim();
    String password = _passwordController.text.trim(); // Get entered password

    if (name.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter both company name and password")),
      );
      return;
    }

    final snapshot = await _dbRef.get();

    if (snapshot.exists) {
      final companies = snapshot.value as Map<dynamic, dynamic>;

      for (var entry in companies.entries) {
        var value = entry.value;
        if (value['companyName'] == name && value['password'] == password) {
          // Check for password match
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => CompanyHomeScreen(companyName: value['companyName']),
            ),
          );
          return;
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Company not found or incorrect password")),
    );
  }

  void _navigateToRegister() {
    Navigator.pushNamed(context, '/companyRegister');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 60),

            // 🎓 Icon/Image on Top (Cap-like styling)
            Icon(Icons.business, size: 100, color: Colors.blue[700]),
            SizedBox(height: 10),

            Text(
              "Company Login",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red, // Set "Company Login" text to red
              ),
            ),
            SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  TextField(
                    controller: _companyNameController,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.business),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: _loginCompany,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      // Set login button background to blue
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      "Login",
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ), // Set text to red
                  ),
                  SizedBox(height: 20),

                  TextButton(
                    onPressed: _navigateToRegister,
                    child: Text(
                      "Don't have an account? Register here",
                      style: TextStyle(color: Colors.blue), // Set text to red
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
