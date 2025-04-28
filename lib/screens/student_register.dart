import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'student_login_screen.dart';

class StudentRegister extends StatefulWidget {
  @override
  _StudentRegisterState createState() => _StudentRegisterState();
}

class _StudentRegisterState extends State<StudentRegister> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();

  String? _selectedDepartment;

  final DatabaseReference _database = FirebaseDatabase.instance.ref().child(
    'students',
  );

  void _registerStudent() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _database.push().set({
          "firstName": _firstNameController.text.trim(),
          "lastName": _lastNameController.text.trim(),
          "email": _emailController.text.trim(),
          "cvFile": "",
          "address": _addressController.text.trim(),
          "department": _selectedDepartment,
          "password": _passwordController.text.trim(),
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration Successful')));

        // Navigate to login screen
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StudentLoginScreen()),
          );
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error saving data: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
                validator:
                    (value) => value!.isEmpty ? 'Enter first name' : null,
              ),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
                validator: (value) => value!.isEmpty ? 'Enter last name' : null,
              ),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email Address'),
                validator:
                    (value) => value!.isEmpty ? 'Enter email address' : null,
              ),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address'),
                validator: (value) => value!.isEmpty ? 'Enter address' : null,
              ),

              // Department dropdown
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: InputDecoration(labelText: 'Department'),
                items:
                    ['IT', 'Management', 'Engineering'].map((
                      String department,
                    ) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(department),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedDepartment = newValue!;
                  });
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Select department'
                            : null,
              ),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) => value!.isEmpty ? 'Enter password' : null,
              ),

              // Re-enter Password
              TextFormField(
                controller: _rePasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Re-enter Password'),
                validator: (value) {
                  if (value!.isEmpty) return 'Re-enter your password';
                  if (value != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: _registerStudent,
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
