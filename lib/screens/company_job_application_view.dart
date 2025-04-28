import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchApplications();
  }

  void fetchApplications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseDatabase.instance
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
          });
        });

        setState(() {
          applications = loadedApps;
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

  void viewCVFile(Map<String, dynamic> application) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CVViewerScreen(
              application: application,
              jobId: widget.jobId,
              onStatusUpdated: () {
                // Refresh the applications list when returning from CV viewer
                fetchApplications();
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Applications for ${widget.jobTitle}"),
        backgroundColor: Colors.blue,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : applications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "No applications found",
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: applications.length,
                padding: EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final app = applications[index];
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
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  app['studentName'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                _buildStatusChip(app['status']),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text("Department: ${app['department']}"),
                            SizedBox(height: 4),
                            Text(
                              "Applied on: ${_formatDate(app['appliedAt'])}",
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.description, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  "View CV",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'accepted':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return "Unknown date";
    try {
      final date = DateTime.parse(dateString);
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}";
    } catch (e) {
      return dateString;
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
  bool isLoading = true;
  bool isUpdatingStatus = false;
  String? errorMessage;

  Future<void> updateApplicationStatus(String status) async {
    setState(() {
      isUpdatingStatus = true;
    });

    try {
      // Reference to the specific application in Firebase
      final applicationRef = FirebaseDatabase.instance
          .ref()
          .child("applications")
          .child(widget.jobId)
          .child(widget.application['studentId']);

      // Update the status
      await applicationRef.update({
        'status': status,
        'reviewedAt': DateTime.now().toIso8601String(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application ${status.toLowerCase()}'),
          backgroundColor: status == 'Accepted' ? Colors.green : Colors.red,
        ),
      );

      // Notify parent to refresh the list
      widget.onStatusUpdated();

      // If accepted or rejected, go back to the list
      Navigator.pop(context);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update application: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _showConfirmationDialog(String action) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm $action'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to $action this application?'),
                SizedBox(height: 10),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                action,
                style: TextStyle(
                  color: action == 'Accept' ? Colors.green : Colors.red,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                updateApplicationStatus(
                  action == 'Accept' ? 'Accepted' : 'Rejected',
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Construct the direct API URL to the PDF
    final String pdfUrl =
        "http://${ServerConfig.serverUrl}/download/${Uri.encodeComponent(widget.application['cvFile'])}";
    final bool canUpdateStatus = widget.application['status'] == 'Pending';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.application['studentName']}\'s CV'),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download functionality can be added here'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            color: _getStatusColor(
              widget.application['status'],
            ).withOpacity(0.1),
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(widget.application['status']),
                  color: _getStatusColor(widget.application['status']),
                ),
                SizedBox(width: 8),
                Text(
                  'Status: ${widget.application['status']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(widget.application['status']),
                  ),
                ),
              ],
            ),
          ),

          // PDF viewer
          Expanded(
            child: SfPdfViewer.network(
              pdfUrl,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              enableDoubleTapZooming: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                setState(() {
                  errorMessage = "Failed to load PDF: ${details.error}";
                });
              },
              key: Key(pdfUrl),
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                setState(() {
                  isLoading = false;
                });
              },
            ),
          ),

          // Accept/Reject buttons
          if (canUpdateStatus)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          isUpdatingStatus
                              ? null
                              : () => _showConfirmationDialog('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close),
                          SizedBox(width: 8),
                          Text('Reject', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          isUpdatingStatus
                              ? null
                              : () => _showConfirmationDialog('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check),
                          SizedBox(width: 8),
                          Text('Accept', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
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
