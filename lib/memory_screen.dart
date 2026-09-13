import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_client.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;
  String _statusText = 'Idle';
  String _resultText = '';
  String _textStatus = ''; // Status specifically for the text box

  // The URL will be fetched dynamically via ApiClient

  @override
  void dispose() {
    _audioRecorder.dispose();
    _textController.dispose();
    super.dispose();
  }

  // --- TEXT MEMORY FUNCTION ---
  Future<void> _submitTextMemory() async {
    print("--- TEXT SAVE BUTTON PRESSED ---"); // Debug flag 1
    
    final text = _textController.text.trim();
    print("Text captured from box: '$text'"); // Debug flag 2

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type a memory first!')),
      );
      return;
    }

    setState(() => _textStatus = 'Connecting to server...');
    
    try {
      final apiUrl = await ApiClient().getWorkingUrl();
      setState(() => _textStatus = 'Sending to server...');

      final response = await http.post(
        Uri.parse('$apiUrl/memory/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 10));

      print("Server responded with Code: ${response.statusCode}"); // Debug flag 3

      if (response.statusCode == 200) {
        setState(() {
          _textController.clear();
          _textStatus = 'Text Memory Saved Successfully!';
        });
      } else {
        setState(() => _textStatus = 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      print("NETWORK EXCEPTION CAUGHT: $e"); // Debug flag 4
      setState(() => _textStatus = 'Backend not reachable.');
    }
  }

  // --- AUDIO MEMORY FUNCTION ---
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _statusText = 'Processing & Vectorizing...';
        });

        if (path != null) {
          await _uploadAudio(path);
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final Directory tempDir = await getTemporaryDirectory();
          final String path = '${tempDir.path}/web_audio.m4a';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );
          
          setState(() {
            _isRecording = true;
            _statusText = 'Recording voice note...';
            _resultText = '';
          });
        } else {
          setState(() => _statusText = 'Microphone permission denied.');
        }
      }
    } catch (e) {
      setState(() => _statusText = 'Error: $e');
    }
  }

  Future<void> _uploadAudio(String path) async {
    try {
      final apiUrl = await ApiClient().getWorkingUrl();
      var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/memory'));
      request.files.add(await http.MultipartFile.fromPath('file', path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _statusText = 'Stored in Database successfully!';
          _resultText = 'Saved Text: "${data['transcription']}"';
        });
      } else {
        setState(() => _statusText = 'Server Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _statusText = 'Backend not reachable.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // 1. TEXT INPUT SECTION
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Add a Text Memory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _textController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Type your memory or reminder here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: _submitTextMemory, // Trigger the function here
                    icon: const Icon(Icons.send),
                    label: const Text('Save Text Memory'),
                  ),
                  const SizedBox(height: 10),
                  if (_textStatus.isNotEmpty)
                    Text(
                      _textStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // 2. AUDIO RECORDING SECTION
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Record a Voice Memory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusText, 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)
                  ),
                  const SizedBox(height: 10),
                  if (_resultText.isNotEmpty)
                    Text(
                      _resultText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}