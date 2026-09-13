import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/api_provider.dart';
import '../theme.dart';
import 'dart:math';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late AnimationController _pulseController;
  late TabController _tabController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  String _currentSource = 'text';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
    _tabController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint("Error starting record: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
      
      if (path != null) {
        final transcribedText = await Provider.of<ApiProvider>(context, listen: false).transcribeAudio(path);
        
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          
          if (transcribedText != null) {
            final api = Provider.of<ApiProvider>(context, listen: false);
            Future<String?> saveFuture = api.createTextMemory(transcribedText, source: 'audio');
            _showVoiceReviewDialog(context, transcribedText, saveFuture, api);
          } else {
            final apiProvider = Provider.of<ApiProvider>(context, listen: false);
            final errorMsg = apiProvider.error ?? 'Unknown error';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transcription Failed: $errorMsg'),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error stopping record: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _saveTextMemory() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final success = await Provider.of<ApiProvider>(context, listen: false).createTextMemory(text, source: _currentSource);
    
    if (mounted) {
      if (success != null) {
        _textController.clear();
        _currentSource = 'text'; // Reset back to default
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Memory saved successfully!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3), // Fades out in few seconds
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save memory.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: 'Voice'),
            Tab(icon: Icon(Icons.edit_note), text: 'Text'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoiceTab(),
          _buildTextTab(),
        ],
      ),
    );
  }

  Widget _buildVoiceTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '00:00',
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 40),
          if (_isProcessing)
            const CircularProgressIndicator(color: AppTheme.primary)
          else if (_isRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final height = 20 + sin((_pulseController.value * pi) + index) * 20;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: height.abs(),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            const SizedBox(height: 40), // Placeholder for waveform
            
          const SizedBox(height: 60),
          if (!_isProcessing)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRecording = !_isRecording;
                });
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: EdgeInsets.all(_isRecording ? 8.0 + (_pulseController.value * 8) : 8.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary.withOpacity(_isRecording ? 0.2 : 0.0),
                    ),
                    child: FloatingActionButton.large(
                      onPressed: () {
                        if (_isRecording) {
                          _stopRecording();
                        } else {
                          _startRecording();
                        }
                      },
                      backgroundColor: _isRecording ? AppTheme.error : AppTheme.primary,
                      child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 36),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Text(
              'Transcribing... Please wait.',
              style: TextStyle(color: Colors.grey),
            )
          else
            Text(
              _isRecording ? 'Tap to stop recording' : 'Tap to start recording',
              style: const TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category chips removed
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Consumer<ApiProvider>(
            builder: (context, api, child) {
              return Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: api.isLoading 
                        ? null 
                        : () => _textController.clear(),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: api.isLoading ? null : _saveTextMemory,
                      icon: api.isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                      label: const Text('Save Memory'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }
  void _showVoiceReviewDialog(BuildContext context, String transcribedText, Future<String?> saveFuture, ApiProvider api) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Voice Memory Saved'),
          content: Text(transcribedText),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final id = await saveFuture;
                if (id != null) {
                  api.deleteMemory(id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Memory discarded')));
                  }
                }
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showVoiceEditDialog(context, transcribedText, saveFuture, api);
              },
              child: const Text('Edit'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved automatically!')));
              },
              child: const Text('Looks Good'),
            ),
          ],
        );
      }
    );
  }

  void _showVoiceEditDialog(BuildContext context, String currentText, Future<String?> saveFuture, ApiProvider api) {
    final TextEditingController editController = TextEditingController(text: currentText);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Voice Memory'),
          content: TextField(
            controller: editController,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel Edit'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != currentText) {
                  final id = await saveFuture;
                  if (id != null) {
                    api.updateMemory(id, newText);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save memory. Please try again.'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
              child: const Text('Save Edits'),
            ),
          ],
        );
      }
    );
  }
}
