import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'cv_upload_screen.dart';
import 'student_home_screen.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  _StudentLoginScreenState createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child(
    "students",
  );

  void loginStudent() async {
    final enteredName = nameController.text.trim();
    final enteredPassword = passwordController.text.trim();

    if (enteredName.isEmpty || enteredPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both name and password")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _userRef.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> users = snapshot.value as Map;
        bool found = false;

        for (final entry in users.entries) {
          final userId = entry.key;
          final user = Map<String, dynamic>.from(entry.value as Map);

          if (user['firstName'] == enteredName &&
              user['password'] == enteredPassword) {
            found = true;

            // Check if CV file exists
            if (user.containsKey('cvFile') &&
                user['cvFile'] != null &&
                user['cvFile'].toString().isNotEmpty) {
              // CV file exists, navigate to home page
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => StudentHomeScreen(
                        studentName: user['firstName'],
                        department: user['department'] ?? '',
                        studentId: userId, // Pass the userId as studentId
                      ),
                ),
              );
            } else {
              // CV file doesn't exist, show dialog to ask user to upload it
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("CV Not Found"),
                        content: const Text(
                          "You need to upload your CV. Would you like to do it now?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to CV upload screen
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => UploadScreen(
                                        studentName: user['firstName'],
                                        studentId:
                                            userId, // Pass userId to upload screen
                                      ),
                                ),
                              );
                            },
                            child: const Text("Yes"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => StudentHomeScreen(
                                        studentName: user['firstName'],
                                        department: user['department'] ?? '',
                                        studentId:
                                            userId, // Pass the userId as studentId
                                      ),
                                ),
                              );
                            },
                            child: const Text("Skip for Now"),
                          ),
                        ],
                      ),
                );
              }
            }
            break;
          }
        }

        if (!found) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Incorrect name or password")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No users registered yet")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error during login: $e")));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void navigateToRegister() {
    Navigator.pushNamed(context, '/studentRegister');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                "Student Login",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Student Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: loginStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Login", style: TextStyle(fontSize: 18)),
                  ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: navigateToRegister,
                child: Text(
                  "Don't have an account? Register here",
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
