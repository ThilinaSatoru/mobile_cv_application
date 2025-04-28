import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AddVacancyScreen extends StatefulWidget {
  final String companyName;

  AddVacancyScreen({required this.companyName});

  @override
  _AddVacancyScreenState createState() => _AddVacancyScreenState();
}

class _AddVacancyScreenState extends State<AddVacancyScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String selectedDepartment = 'IT';
  final DatabaseReference _vacancyRef = FirebaseDatabase.instance.ref(
    "vacancies",
  );

  void _submitVacancy() async {
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    await _vacancyRef.push().set({
      'jobTitle': _titleController.text,
      'description': _descController.text,
      'location': _locationController.text,
      'department': selectedDepartment,
      'companyName': widget.companyName,
    });

    Navigator.pop(context); // Go back to company home screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Vacancy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Job Title'),
            ),
            TextField(
              controller: _descController,
              decoration: InputDecoration(labelText: 'Job Description'),
              maxLines: 3,
            ),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(labelText: 'Job Location'),
            ),
            DropdownButtonFormField<String>(
              value: selectedDepartment,
              items:
                  ['IT', 'Management', 'Engineering'].map((dept) {
                    return DropdownMenuItem(value: dept, child: Text(dept));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDepartment = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Department'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitVacancy,
              child: Text('Add Vacancy'),
            ),
          ],
        ),
      ),
    );
  }
}
