import 'package:flutter/material.dart';

import '../model/job.dart';
import 'company_job_application_view.dart';

class CompanyJobDetailsScreen extends StatelessWidget {
  final Job job;
  final String companyName;

  CompanyJobDetailsScreen({required this.job, required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.jobTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Department: ${job.department}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text("Location: ${job.location}", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text("Company: ${job.companyName}", style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              "Description:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(job.description, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ViewApplicationsScreen(
                            jobId: job.id,
                            jobTitle: job.jobTitle,
                          ),
                    ),
                  );
                },
                child: Text("View Applications"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
