import 'package:firebase_database/firebase_database.dart';

class Student {
  final String id;
  final String name;
  final String department;

  Student.fromSnapshot(DataSnapshot snapshot)
    : id = snapshot.key ?? '',
      name = snapshot.child('firstName').value?.toString() ?? '',
      department = snapshot.child('department').value?.toString() ?? '';
}
