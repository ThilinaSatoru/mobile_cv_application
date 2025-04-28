import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;

import '../globals.dart';

class CVFormScreen extends StatelessWidget {
  const CVFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Resume Filter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UploadScreen()),
                  ),
              child: Text('Upload Resume'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  ),
              child: Text('Search Resumes'),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _uploadResume() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://${ServerConfig.serverUrl}/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      try {
        var response = await request.send();
        var responseData = await http.Response.fromStream(response);

        if (response.statusCode == 200) {
          var jsonResponse = jsonDecode(responseData.body);
          setState(() {
            _status =
                'Uploaded: ${jsonResponse['filename']}\n'
                'Name: ${jsonResponse['info']['name']}\n'
                'Email: ${jsonResponse['info']['email']}';
          });
        } else {
          setState(() {
            _status = 'Error: ${jsonDecode(responseData.body)['detail']}';
          });
        }
      } catch (e) {
        setState(() {
          _status = 'Error: $e';
        });
      }
    } else {
      setState(() {
        _status = 'No file selected';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Resume')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? SpinKitCircle(color: Colors.blue)
                : ElevatedButton(
                  onPressed: _uploadResume,
                  child: Text('Pick and Upload PDF'),
                ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_status, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  bool _isLoading = false;
  List<dynamic> _results = [];

  Future<void> _searchResumes() async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      var response = await http.post(
        Uri.parse('http://${ServerConfig.serverUrl}/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': _queryController.text}),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        setState(() {
          _results = jsonResponse['results'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${jsonDecode(response.body)['detail']}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Resumes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Enter job description or skills',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? SpinKitCircle(color: Colors.blue)
                : ElevatedButton(
                  onPressed: _searchResumes,
                  child: Text('Search'),
                ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  var result = _results[index];
                  return Card(
                    child: ListTile(
                      title: Text('Resume: ${result['file']}'),
                      subtitle: Text(
                        'Score: ${(result['match_score'] * 100).toStringAsFixed(2)}%\n'
                        'Name: ${result['info']['name']}\n'
                        'Skills: ${result['info']['skills'].join(', ')}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}
