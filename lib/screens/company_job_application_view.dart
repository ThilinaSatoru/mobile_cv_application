import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../globals.dart';

class ViewApplicationsScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const ViewApplicationsScreen({
    Key? key,
    required this.jobId,
    required this.jobTitle,
  }) : super(key: key);

  @override
  State<ViewApplicationsScreen> createState() => _ViewApplicationsScreenState();
}

class _ViewApplicationsScreenState extends State<ViewApplicationsScreen> {
  List<Map<String, dynamic>> applications = [];
  List<Map<String, dynamic>> filteredApplications = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  String? filterStatus;
  String sortBy = 'appliedAt';
  bool sortAscending = false;

  // Search functionality variables
  final _queryController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchApplications();
    searchController.addListener(_filterApplications);
  }

  @override
  void dispose() {
    searchController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> fetchApplications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.jobId)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        List<Map<String, dynamic>> loadedApps = [];

        data.forEach((studentId, appData) {
          final app = Map<String, dynamic>.from(appData as Map);
          loadedApps.add({
            'studentId': studentId,
            'studentName': app['studentName'] ?? 'Unknown',
            'department': app['department'] ?? '',
            'status': app['status'] ?? 'Pending',
            'appliedAt': app['appliedAt'] ?? '',
            'cvFile': app['cvFile'] ?? '',
            'email': app['email'] ?? '',
            'phone': app['phone'] ?? '',
            'skills': app['skills'] ?? [],
            'education': app['education'] ?? '',
            'experience': app['experience'] ?? '',
          });
        });

        setState(() {
          applications = loadedApps;
          _sortApplications();
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading applications: $error')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _searchResumes() async {
    if (_queryController.text.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      // Get the current vacancy's department
      final currentDepartment = await _fetchCurrentVacancyDepartment();

      var response = await http.post(
        Uri.parse('http://${ServerConfig.serverUrl}/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': _queryController.text,
          'department': currentDepartment, // Send department for filtering
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        // If backend doesn't filter by department, we can filter results here
        List<dynamic> filteredResults = [];
        for (var result in jsonResponse['results']) {
          // Check student department from either results or match with our applications list
          String? studentDepartment = result['info']['department'];

          // If department not in result info, try to find in our applications
          if (studentDepartment == null) {
            // Find matching student in applications
            var matchingApp = applications.firstWhere(
                  (app) => app['cvFile'] == result['file'],
              orElse: () => {},
            );

            if (matchingApp.isNotEmpty) {
              studentDepartment = matchingApp['department'];
            }
          }

          // Only include results matching the current vacancy's department
          if (studentDepartment == currentDepartment) {
            filteredResults.add(result);
          }
        }

        setState(() {
          _searchResults = filteredResults;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${jsonDecode(response.body)['detail']}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      _isSearching = false;
    });
  }

// Helper method to fetch the current vacancy's department
  Future<String> _fetchCurrentVacancyDepartment() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child("vacancies")
          .child(widget.jobId)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data['department'] ?? '';
      }
    } catch (e) {
      print('Error fetching vacancy department: $e');
    }

    return ''; // Return empty string if department not found
  }

// Update how we display search results to show department info
  Widget _buildSearchResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Search Results (${_searchResults.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No matching resumes found in this department",
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              var result = _searchResults[index];
              // Try to find matching application
              var matchingApp = applications.firstWhere(
                    (app) => app['cvFile'] == result['file'],
                orElse: () => {},
              );

              // Get department from result or matching application
              String department = result['info']['department'] ??
                  (matchingApp.isNotEmpty
                      ? matchingApp['department']
                      : 'Unknown');

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ListTile(
                  title: Text(
                    result['info']['name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.school, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            department,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Resume match score: ${(result['match_score'] * 100)
                            .toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.green[700]),
                      ),
                      if (result['info']['skills'] != null) ...[
                        SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: (result['info']['skills'] as List<dynamic>)
                              .take(3)
                              .map((skill) =>
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Text(
                                  skill.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                  trailing: matchingApp.isNotEmpty
                      ? _buildStatusChip(matchingApp['status'])
                      : Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Not Applied',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  onTap: () {
                    if (matchingApp.isNotEmpty) {
                      viewCVFile(matchingApp);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'No application found for this resume in this job')),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _filterApplications() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && filterStatus == null) {
        filteredApplications = List.from(applications);
      } else {
        filteredApplications = applications.where((app) {
          // Filter by search query
          final matchesQuery = query.isEmpty ||
              app['studentName'].toString().toLowerCase().contains(query) ||
              app['department'].toString().toLowerCase().contains(query) ||
              app['email'].toString().toLowerCase().contains(query) ||
              (app['skills'] != null &&
                  app['skills'].toString().toLowerCase().contains(query));

          // Filter by status
          final matchesStatus = filterStatus == null ||
              app['status'].toString().toLowerCase() ==
                  filterStatus!.toLowerCase();

          return matchesQuery && matchesStatus;
        }).toList();
      }

      _sortApplications();
    });
  }

  void _sortApplications() {
    filteredApplications.sort((a, b) {
      dynamic valueA, valueB;

      switch (sortBy) {
        case 'studentName':
          valueA = a['studentName'];
          valueB = b['studentName'];
          break;
        case 'department':
          valueA = a['department'];
          valueB = b['department'];
          break;
        case 'status':
          valueA = a['status'];
          valueB = b['status'];
          break;
        case 'appliedAt':
        default:
          try {
            valueA = a['appliedAt'].isNotEmpty
                ? DateTime.parse(a['appliedAt'])
                : DateTime(1900);
            valueB = b['appliedAt'].isNotEmpty
                ? DateTime.parse(b['appliedAt'])
                : DateTime(1900);
          } catch (e) {
            valueA = a['appliedAt'];
            valueB = b['appliedAt'];
          }
      }

      int result;
      if (valueA == null && valueB == null) {
        result = 0;
      } else if (valueA == null) {
        result = -1;
      } else if (valueB == null) {
        result = 1;
      } else if (valueA is DateTime && valueB is DateTime) {
        result = valueA.compareTo(valueB);
      } else {
        result = valueA.toString().compareTo(valueB.toString());
      }

      return sortAscending ? result : -result;
    });
  }

  void viewCVFile(Map<String, dynamic> application) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CVViewerScreen(
              application: application,
              jobId: widget.jobId,
              onStatusUpdated: () {
                fetchApplications();
              },
            ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Column(
      children: [
        // Resume search section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: 'Search resumes by job description or skills',
                  border: OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_queryController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _queryController.clear();
                              _searchResults.clear();
                              _isSearching = false;
                            });
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.search),
                        onPressed: _searchResumes,
                      ),
                    ],
                  ),
                ),
                onSubmitted: (_) => _searchResumes(),
              ),
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SpinKitCircle(color: Colors.blue, size: 20),
                ),
            ],
          ),
        ),

        // Application search section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search applications by name, department, skills...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  searchController.clear();
                },
              )
                  : null,
            ),
          ),
        ),
        SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Status filter chips
              ChoiceChip(
                label: Text('All'),
                selected: filterStatus == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      filterStatus = null;
                      _filterApplications();
                    });
                  }
                },
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Pending'),
                selected: filterStatus == 'pending',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      filterStatus = 'pending';
                      _filterApplications();
                    });
                  }
                },
                backgroundColor: Colors.orange.withOpacity(0.1),
                selectedColor: Colors.orange.withOpacity(0.3),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Accepted'),
                selected: filterStatus == 'accepted',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      filterStatus = 'accepted';
                      _filterApplications();
                    });
                  }
                },
                backgroundColor: Colors.green.withOpacity(0.1),
                selectedColor: Colors.green.withOpacity(0.3),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Rejected'),
                selected: filterStatus == 'rejected',
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      filterStatus = 'rejected';
                      _filterApplications();
                    });
                  }
                },
                backgroundColor: Colors.red.withOpacity(0.1),
                selectedColor: Colors.red.withOpacity(0.3),
              ),
              SizedBox(width: 16),

              // Sort options
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: sortBy,
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sortAscending ? Icons.arrow_upward : Icons
                          .arrow_downward,
                          size: 16),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  underline: SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        if (sortBy == newValue) {
                          sortAscending = !sortAscending;
                        } else {
                          sortBy = newValue;
                          sortAscending = false;
                        }
                        _sortApplications();
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                        value: 'appliedAt', child: Text('Date Applied')),
                    DropdownMenuItem(value: 'studentName', child: Text('Name')),
                    DropdownMenuItem(
                        value: 'department', child: Text('Department')),
                    DropdownMenuItem(value: 'status', child: Text('Status')),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),

        // Stats bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'Showing ${filteredApplications.length} of ${applications
                    .length} applications',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Spacer(),
              Text(
                _getStatusCount('accepted'),
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              Text(' · ', style: TextStyle(color: Colors.grey)),
              Text(
                _getStatusCount('pending'),
                style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              Text(' · ', style: TextStyle(color: Colors.grey)),
              Text(
                _getStatusCount('rejected'),
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }

  String _getStatusCount(String status) {
    int count = applications.where((app) =>
    app['status'].toString().toLowerCase() == status.toLowerCase()).length;
    return '$count ${status.capitalize()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Applications for ${widget.jobTitle}"),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Search, filter, and sort bar
          _buildSearchAndFilterBar(),

          // Main content
          Expanded(
            child: _searchResults.isNotEmpty
                ? _buildSearchResults()
                : isLoading
                ? const Center(child: CircularProgressIndicator())
                : applications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No applications found",
                    style: TextStyle(
                        fontSize: 18, color: Colors.grey[700]),
                  ),
                ],
              ),
            )
                : filteredApplications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No matching applications found",
                    style: TextStyle(
                        fontSize: 18, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        filterStatus = null;
                        _filterApplications();
                      });
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Clear filters'),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredApplications.length,
              padding: EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final app = filteredApplications[index];
                return _buildApplicationCard(app);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app) {
    List<String> skills = [];
    if (app['skills'] != null) {
      if (app['skills'] is List) {
        skills = List<String>.from(app['skills']);
      } else if (app['skills'] is String) {
        skills =
            app['skills'].toString().split(',').map((s) => s.trim()).toList();
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (app['cvFile'] != null && app['cvFile'].isNotEmpty) {
            viewCVFile(app);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('CV file not available')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header with name and status
            Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app['studentName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (app['email'] != null && app['email'].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              app['email'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(app['status'] ?? 'Pending'),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Department and date
                  Row(
                    children: [
                      Icon(Icons.school, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        app['department'] ?? 'No department',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                      Spacer(),
                      Icon(Icons.calendar_today, size: 16,
                          color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        app['appliedAt'] != null && app['appliedAt'].isNotEmpty
                            ? _formatDate(app['appliedAt'])
                            : 'Unknown date',
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ],
                  ),

                  // Phone number if available
                  if (app['phone'] != null && app['phone'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 8),
                          Text(
                            app['phone'],
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),

                  // Skills section
                  if (skills.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skills:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Wrap(
                            spacing: 6.0,
                            runSpacing: 6.0,
                            children: skills.map((skill) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Text(
                                  skill,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Footer - View Resume button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (app['cvFile'] != null && app['cvFile'].isNotEmpty) {
                        viewCVFile(app);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('CV file not available')),
                        );
                      }
                    },
                    icon: Icon(Icons.description),
                    label: Text('View Resume'),
                  ),
                  // Row(
                  //   children: [
                  //     IconButton(
                  //       icon: Icon(Icons.email_outlined),
                  //       tooltip: 'Send Email',
                  //       onPressed: () {
                  //         // Implement email functionality
                  //         if (app['email'] != null && app['email'].isNotEmpty) {
                  //           // Add email functionality here
                  //           ScaffoldMessenger.of(context).showSnackBar(
                  //             SnackBar(content: Text('Email feature not implemented yet')),
                  //           );
                  //         } else {
                  //           ScaffoldMessenger.of(context).showSnackBar(
                  //             SnackBar(content: Text('Email not available')),
                  //           );
                  //         }
                  //       },
                  //     ),
                  //     IconButton(
                  //       icon: Icon(Icons.more_vert),
                  //       onPressed: () {
                  //         _showOptionsMenu(context, app);
                  //       },
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'accepted':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            status.capitalize(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      // Format the date in a user-friendly way
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showOptionsMenu(BuildContext context,
      Map<String, dynamic> application) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  application['studentName'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text('Application Options'),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.person, color: Colors.blue),
                title: Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement view profile functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(
                        'View profile functionality not implemented yet')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.thumb_up, color: Colors.green),
                title: Text('Accept Application'),
                onTap: () {
                  Navigator.pop(context);
                  _updateApplicationStatus(application, 'accepted');
                },
              ),
              ListTile(
                leading: Icon(Icons.thumb_down, color: Colors.red),
                title: Text('Reject Application'),
                onTap: () {
                  Navigator.pop(context);
                  _updateApplicationStatus(application, 'rejected');
                },
              ),
              ListTile(
                leading: Icon(Icons.restore, color: Colors.orange),
                title: Text('Mark as Pending'),
                onTap: () {
                  Navigator.pop(context);
                  _updateApplicationStatus(application, 'pending');
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateApplicationStatus(Map<String, dynamic> application,
      String newStatus) async {
    final studentId = application['studentId'];

    try {
      await FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.jobId)
          .child(studentId)
          .update({'status': newStatus});

      // Update local state
      setState(() {
        for (var app in applications) {
          if (app['studentId'] == studentId) {
            app['status'] = newStatus;
            break;
          }
        }

        // Update filtered applications too
        for (var app in filteredApplications) {
          if (app['studentId'] == studentId) {
            app['status'] = newStatus;
            break;
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Application status updated to ${_capitalizeString(newStatus)}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $error')),
      );
    }
  }
}

class CVViewerScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  final String jobId;
  final Function onStatusUpdated;

  const CVViewerScreen({
    Key? key,
    required this.application,
    required this.jobId,
    required this.onStatusUpdated,
  }) : super(key: key);

  @override
  State<CVViewerScreen> createState() => _CVViewerScreenState();
}

class _CVViewerScreenState extends State<CVViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool isLoading = true;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.application['studentName']}\'s Resume'),
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            onSelected: (String status) {
              _updateApplicationStatus(status);
            },
            itemBuilder: (BuildContext context) =>
            [
              PopupMenuItem<String>(
                value: 'accepted',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Accept'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'rejected',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reject'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Pending'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            color: _getStatusColor(widget.application['status']).withOpacity(
                0.1),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(widget.application['status']),
                  color: _getStatusColor(widget.application['status']),
                ),
                SizedBox(width: 8),
                Text(
                  'Status: ${_capitalizeString(
                      widget.application['status'] ?? 'Pending')}',
                  style: TextStyle(
                    color: _getStatusColor(widget.application['status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // PDF Viewer
          Expanded(
            child: widget.application['cvFile'] != null &&
                widget.application['cvFile'].isNotEmpty
                ? _buildPdfViewer(
                'http://${ServerConfig.serverUrl}/download/${widget
                    .application['cvFile']}')
                : Center(
              child: Text('No CV file available'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(String fileUrl) {
    return Stack(
      children: [
        SfPdfViewer.network(
          fileUrl,
          controller: _pdfViewerController,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              isLoading = false;
            });
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            setState(() {
              isLoading = false;
              errorMessage = details.error;
            });
          },
        ),
        if (isLoading)
          Center(
            child: SpinKitCircle(
              color: Colors.blue,
              size: 50.0,
            ),
          ),
        if (errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load PDF',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(errorMessage!),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _updateApplicationStatus(String newStatus) async {
    final studentId = widget.application['studentId'];

    try {
      await FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.jobId)
          .child(studentId)
          .update({'status': newStatus});

      setState(() {
        widget.application['status'] = newStatus;
      });

      widget.onStatusUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Application status updated to ${newStatus.capitalize()}')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $error')),
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }
}

// Extension for capitalizing strings
extension StringExtension on String {
  String capitalize() {
    return this.isNotEmpty
        ? '${this[0].toUpperCase()}${this.substring(1)}'
        : '';
  }
}


String _capitalizeString(String input) {
  if (input.isEmpty) return '';
  return '${input[0].toUpperCase()}${input.substring(1)}';
}