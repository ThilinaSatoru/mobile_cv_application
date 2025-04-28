import 'package:intl/intl.dart';

class Job {
  final String id;
  final String jobTitle;
  final String department;
  final String location;
  final String companyName;
  final String description;
  final String? jobType;
  final String? salary;
  final String? deadline;
  final String? requirements;
  final String? contactEmail;

  Job({
    required this.id,
    required this.jobTitle,
    required this.department,
    required this.location,
    required this.companyName,
    required this.description,
    this.jobType,
    this.salary,
    this.deadline,
    this.requirements,
    this.contactEmail,
  });

  factory Job.fromMap(String id, Map<String, dynamic> map) {
    return Job(
      id: id,
      jobTitle: map['jobTitle'] ?? 'No Title',
      department: map['department'] ?? 'No Department',
      location: map['location'] ?? 'Location Not Specified',
      companyName: map['companyName'] ?? 'Company Not Specified',
      description: map['description'] ?? 'No Description Provided',
      jobType: map['jobType'],
      salary: map['salary'],
      deadline: map['deadline'],
      requirements: map['requirements'],
      contactEmail: map['contactEmail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobTitle': jobTitle,
      'department': department,
      'location': location,
      'companyName': companyName,
      'description': description,
      if (jobType != null) 'jobType': jobType,
      if (salary != null) 'salary': salary,
      if (deadline != null) 'deadline': deadline,
      if (requirements != null) 'requirements': requirements,
      if (contactEmail != null) 'contactEmail': contactEmail,
    };
  }

  String get formattedDeadline {
    if (deadline == null) return 'No Deadline';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(deadline!));
    } catch (e) {
      return deadline!;
    }
  }

  bool get isExpired {
    if (deadline == null) return false;
    try {
      return DateTime.parse(deadline!).isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }
}
