import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:test_cv/screens/student_job_details_screen.dart';

import '../model/job.dart';

class StudentHomeScreen extends StatefulWidget {
  final String department;
  final String studentName;
  final String studentId;

  StudentHomeScreen({
    required this.department,
    required this.studentName,
    required this.studentId,
    super.key,
  });

  @override
  _StudentHomeScreenState createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final DatabaseReference _vacancyRef = FirebaseDatabase.instance.ref(
    "vacancies",
  );
  final DatabaseReference _applicationsRef = FirebaseDatabase.instance.ref(
    "applications",
  );
  bool _isLoading = true;
  Map<String, bool> _appliedJobs = {};

  @override
  void initState() {
    super.initState();
    // Validate student ID at initialization
    if (widget.studentId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid student ID. Please login again.'),
            ),
          );
        }
      });
    } else {
      _fetchAppliedJobs();
    }
  }

  Future<void> _fetchAppliedJobs() async {
    if (widget.studentId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final snapshot =
          await _applicationsRef
              .orderByChild('studentId')
              .equalTo(widget.studentId)
              .get();

      setState(() {
        _appliedJobs.clear();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, application) {
            _appliedJobs[key] = true;
          });
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching applications: $e')),
        );
      }
    }
  }

  Widget _buildVacancyItem(Job job) {
    final hasApplied = _appliedJobs.containsKey(job.id);
    final isExpired = job.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      color: isExpired ? Colors.grey[200] : null,
      child: InkWell(
        onTap: () {
          // Validate student ID before navigation
          if (widget.studentId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid student ID. Please login again.'),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => JobDetailsScreen(
                    job: job,
                    studentName: widget.studentName,
                    studentId: widget.studentId,
                    department: widget.department,
                    hasApplied: hasApplied,
                    onApplicationSuccess: () {
                      setState(() {
                        _appliedJobs[job.id] = true;
                      });
                    },
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job.jobTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isExpired ? Colors.grey : null,
                      ),
                    ),
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        'Expired',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.companyName,
                style: TextStyle(
                  fontSize: 16,
                  color: isExpired ? Colors.grey : null,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    job.location,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  const Icon(Icons.work, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    job.jobType ?? 'Not specified',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Deadline: ${job.formattedDeadline}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              if (hasApplied)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      'Applied',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.department} Vacancies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _fetchAppliedJobs();
            },
          ),
        ],
      ),
      body:
          widget.studentId.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Student ID is missing.',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please try logging in again.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // Student info header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(
                            widget.studentName.isNotEmpty
                                ? widget.studentName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.department,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Vacancies list
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : FirebaseAnimatedList(
                              query: _vacancyRef,
                              defaultChild: const Center(
                                child: Text('Loading vacancies...'),
                              ),
                              itemBuilder: (
                                context,
                                snapshot,
                                animation,
                                index,
                              ) {
                                if (snapshot.value == null) {
                                  return const SizedBox.shrink();
                                }

                                try {
                                  final job = Job.fromMap(
                                    snapshot.key!,
                                    Map<String, dynamic>.from(
                                      snapshot.value as Map,
                                    ),
                                  );

                                  // Only show jobs from the student's department
                                  if (job.department.trim().toUpperCase() !=
                                      widget.department.trim().toUpperCase()) {
                                    return const SizedBox.shrink();
                                  }

                                  return _buildVacancyItem(job);
                                } catch (e) {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
