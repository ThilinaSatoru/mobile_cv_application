import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../model/job.dart';
import 'company_add_vacancy_screen.dart';
import 'company_job_details.dart';

class CompanyHomeScreen extends StatefulWidget {
  final String companyName;

  CompanyHomeScreen({required this.companyName});

  @override
  _CompanyHomeScreenState createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  final DatabaseReference _vacancyRef = FirebaseDatabase.instance.ref(
    "vacancies",
  );

  List<Job> companyVacancies = [];

  @override
  void initState() {
    super.initState();
    fetchVacancies();
  }

  void fetchVacancies() async {
    final snapshot = await _vacancyRef.get();

    if (snapshot.exists) {
      List<Job> tempList = [];

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final jobMap = Map<String, dynamic>.from(value as Map);
        if (jobMap['companyName'] == widget.companyName) {
          tempList.add(Job.fromMap(key, jobMap));
        }
      });

      setState(() {
        companyVacancies = tempList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome ${widget.companyName}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            companyVacancies.isEmpty
                ? Center(child: Text("No vacancies added yet"))
                : ListView.builder(
                  itemCount: companyVacancies.length,
                  itemBuilder: (context, index) {
                    final job = companyVacancies[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(job.jobTitle),
                        subtitle: Text('${job.department} • ${job.location}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CompanyJobDetailsScreen(
                                    job: job,
                                    companyName: widget.companyName,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddVacancyScreen(companyName: widget.companyName),
            ),
          ).then((_) => fetchVacancies()); // Refresh after adding
        },
        tooltip: "Add New Vacancy",
        child: Icon(Icons.add),
      ),
    );
  }
}
