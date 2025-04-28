import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:test_cv/screens/student_home_screen.dart';

import '../globals.dart';

class UploadScreen extends StatefulWidget {
  final String studentName;
  final String studentId;

  const UploadScreen({
    required this.studentName,
    required this.studentId, // Required parameter
    Key? key,
  }) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child(
    "students",
  );

  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showErrorSnackBar('No internet connection available');
        return;
      }

      final response = await http
          .get(Uri.parse('http://${ServerConfig.serverUrl}/health'))
          .timeout(
            Duration(seconds: 5),
            onTimeout:
                () => throw TimeoutException('Server health check timed out'),
          );

      if (response.statusCode != 200) {
        _showErrorSnackBar(
          'Server is reachable but returned error: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      _showErrorSnackBar(
        'Server is not responding. Please check server status.',
      );
    } on SocketException catch (e) {
      _showErrorSnackBar(
        'Network error: ${e.message}. Check if server is running.',
      );
    } catch (e) {
      _showErrorSnackBar('Error checking server: $e');
    }
  }

  Future<String?> _getUserId(String studentName) async {
    try {
      final snapshot =
          await _userRef.orderByChild('firstName').equalTo(studentName).get();
      if (snapshot.exists) {
        final users = Map<String, dynamic>.from(snapshot.value as Map);
        return users.keys.first;
      }
      return null;
    } catch (e) {
      debugPrint("Error getting user ID: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserData(String studentName) async {
    try {
      final snapshot =
          await _userRef.orderByChild('firstName').equalTo(studentName).get();
      if (snapshot.exists) {
        final users = Map<String, dynamic>.from(snapshot.value as Map);
        return Map<String, dynamic>.from(users.values.first);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user data: $e");
      return null;
    }
  }

  Future<void> _selectPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
  }

  Future<void> _uploadResume() async {
    if (_selectedFilePath == null) {
      _showErrorSnackBar('No file selected');
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0;
    });

    final dio = Dio();
    try {
      // Check connectivity first
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw SocketException('No internet connection');
      }

      File file = File(_selectedFilePath!);

      // Create form data
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: _selectedFileName,
        ),
        'student_name': widget.studentName,
      });

      // Send the request with progress tracking
      final response = await dio.post(
        'http://${ServerConfig.serverUrl}/upload',
        data: formData,
        options: Options(
          sendTimeout: Duration(seconds: ServerConfig.timeoutSeconds),
          receiveTimeout: Duration(seconds: ServerConfig.timeoutSeconds),
        ),
        onSendProgress: (int sent, int total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      // Process the response
      if (response.statusCode == 200) {
        final userId = await _getUserId(widget.studentName);
        if (userId != null) {
          await _userRef.child(userId).update({
            'cvFile': _selectedFileName,
            'uploadTimestamp': ServerValue.timestamp,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CV uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        final userData = await _fetchUserData(widget.studentName);
        if (userData != null) {
          if (mounted) {
            // Reduced delay to improve UX
            Future.delayed(Duration(milliseconds: 500), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StudentHomeScreen(
                        studentName: widget.studentName,
                        department: userData['department'] ?? '',
                        studentId: '',
                      ),
                ),
              );
            });
          }
        } else {
          _showErrorSnackBar('Could not fetch user data');
        }
      } else {
        String errorMsg = 'Server error: ${response.statusCode}';
        if (response.data is Map) {
          errorMsg = response.data['detail'] ?? errorMsg;
        }
        _showErrorSnackBar(errorMsg);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        _showErrorSnackBar(
          'Connection timed out. The server may be overloaded or unreachable.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        _showErrorSnackBar(
          'Network error. Check your connection and server status.',
        );
      } else {
        _showErrorSnackBar('Error: ${e.message}');
      }
    } on SocketException catch (e) {
      _showErrorSnackBar(
        'Network error: ${e.message}. Check your connection and server status.',
      );
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Back to Login',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/studentLogin');
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate to login screen if user attempts to go back
        Navigator.pushReplacementNamed(context, '/studentLogin');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Resume'),
          elevation: 2,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/studentLogin');
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Upload your CV or Resume',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please select a PDF file to upload',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // File selection indicator
                if (_selectedFileName != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, color: Colors.blue),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _selectedFileName!,
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                // Upload progress indicator
                if (_isUploading && _uploadProgress > 0)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),

                // Loading spinner or action buttons
                if (_isLoading)
                  const SpinKitCircle(color: Colors.blue, size: 50)
                else
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _selectPdfFile,
                        icon: Icon(Icons.file_present),
                        label: Text('Select PDF File'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed:
                            _selectedFilePath != null ? _uploadResume : null,
                        icon: Icon(Icons.upload),
                        label: Text('Upload Resume'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          backgroundColor: Colors.green,
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
