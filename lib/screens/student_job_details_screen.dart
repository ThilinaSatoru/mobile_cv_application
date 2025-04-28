import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/job.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;
  final String studentName;
  final String studentId;
  final String department;
  final bool hasApplied;
  final VoidCallback onApplicationSuccess;

  JobDetailsScreen({
    required this.job,
    required this.studentName,
    required this.studentId,
    required this.department,
    required this.hasApplied,
    required this.onApplicationSuccess,
    Key? key,
  }) : super(key: key) {
    assert(studentId.isNotEmpty, 'Student ID cannot be empty');
    assert(department.isNotEmpty, 'Department cannot be empty');
    assert(studentName.isNotEmpty, 'Student name cannot be empty');
  }

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isApplying = false;
  String? _cvFile;
  bool _isLoading = true;
  String? _applicationStatus;
  String? _reviewDate;

  @override
  void initState() {
    super.initState();
    // Use a short delay to avoid initialization issues
    Future.delayed(Duration.zero, () {
      _fetchStudentCv();
      _fetchApplicationStatus();
    });
  }

  Future<void> _fetchApplicationStatus() async {
    try {
      print(
        "🔍 Checking application status for job: ${widget.job.id}, student: ${widget.studentId}",
      );

      final DatabaseReference applicationRef = FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.job.id)
          .child(widget.studentId);

      final snapshot = await applicationRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _applicationStatus = data['status'] as String?;
          _reviewDate =
              data.containsKey('reviewedAt')
                  ? data['reviewedAt'] as String?
                  : null;
        });
        print("📊 Application status found: $_applicationStatus");
      } else {
        print("📊 No application found for this job and student");
      }
    } catch (e) {
      print("❌ Error fetching application status: $e");
    }
  }

  Future<void> _fetchStudentCv() async {
    try {
      print("🐛 Fetching CV for student ID: '${widget.studentId}'");

      if (widget.studentId.isEmpty) {
        print("❌ Error: Student ID is empty");
        setState(() => _isLoading = false);
        return;
      }

      final DatabaseReference studentRef = FirebaseDatabase.instance
          .ref()
          .child("students")
          .child(widget.studentId);

      print("🔥 Database path: ${studentRef.path}");

      final snapshot = await studentRef.get();
      print("📊 Snapshot exists: ${snapshot.exists}");

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print("📦 Student data: ${data.keys.toList()}");

        if (data.containsKey('cvFile') &&
            data['cvFile'] != null &&
            data['cvFile'].toString().isNotEmpty) {
          print("✅ Found CV: ${data['cvFile']}");
          setState(() => _cvFile = data['cvFile'].toString());
        } else {
          print("❌ CV field missing or empty");
          setState(() => _cvFile = null);
        }
      } else {
        print("❌ No student found at this path");
      }
    } catch (e) {
      print("❌ Error fetching CV: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitApplication() async {
    if (_cvFile == null || _cvFile!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your CV before applying")),
      );
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final applicationRef = FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.job.id)
          .child(widget.studentId);

      await applicationRef.set({
        "studentId": widget.studentId,
        "studentName": widget.studentName,
        "department": widget.department,
        "cvFile": _cvFile,
        "jobTitle": widget.job.jobTitle,
        "companyName": widget.job.companyName,
        "jobId": widget.job.id,
        "appliedAt": DateTime.now().toIso8601String(),
        "status": "Pending",
      });

      setState(() {
        _applicationStatus = "Pending";
      });

      widget.onApplicationSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application submitted successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error applying: $e")));
    } finally {
      setState(() {
        _isApplying = false;
      });
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusView() {
    // Set colors based on status
    Color statusColor;
    IconData statusIcon;

    switch (_applicationStatus) {
      case "Accepted":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case "Rejected":
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case "Pending":
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 8),
              Text(
                "Application Status: $_applicationStatus",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (_reviewDate != null) ...[
            const SizedBox(height: 8),
            Text(
              "Reviewed on: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(_reviewDate!))}",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Job Details")),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.jobTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.job.companyName,
                      style: const TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                    const Divider(height: 32),

                    // Display application status if applied
                    if (_applicationStatus != null) ...[
                      _buildApplicationStatusView(),
                      const SizedBox(height: 16),
                    ],

                    _buildInfoRow(
                      "Location",
                      widget.job.location ?? "Not specified",
                    ),
                    _buildInfoRow("Department", widget.job.department),
                    _buildInfoRow(
                      "Type",
                      widget.job.jobType ?? "Not specified",
                    ),
                    _buildInfoRow(
                      "Salary",
                      widget.job.salary ?? "Not specified",
                    ),

                    if (widget.job.deadline != null)
                      _buildInfoRow(
                        "Deadline",
                        DateFormat(
                          'MMM dd, yyyy',
                        ).format(DateTime.parse(widget.job.deadline!)),
                      ),

                    const SizedBox(height: 16),
                    const Text(
                      "Job Description",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.job.description ?? 'No description provided.',
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 32),
                    // Show CV status for debugging
                    if (_cvFile == null || _cvFile!.trim().isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "No CV found. Please upload a CV in your profile.",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),

                    // Only show apply button if not already applied
                    if (_applicationStatus == null)
                      Center(
                        child:
                            _isApplying
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                  onPressed: _submitApplication,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 32.0,
                                      vertical: 12.0,
                                    ),
                                    child: Text(
                                      "Apply Now",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                      ),
                  ],
                ),
              ),
    );
  }
}
