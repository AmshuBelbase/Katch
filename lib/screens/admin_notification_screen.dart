import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/api_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  List<Map<String, String>> appFeatures = [];
  bool isLoadingFeatures = true;

  @override
  void initState() {
    super.initState();
    _fetchFeatures();
  }

  Future<void> _fetchFeatures() async {
    try {
      final response = await Supabase.instance.client.from('app_features').select('*');
      setState(() {
        appFeatures = (response as List).map((f) => {
          'id': f['id'].toString(),
          'name': f['name'].toString(),
          'screen': f['screen'].toString(),
          'description': f['description'].toString(),
          'usage': f['usage'].toString(),
        }).toList();
        isLoadingFeatures = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load features: $e')),
        );
        setState(() => isLoadingFeatures = false);
      }
    }
  }

  String? selectedFeatureId;
  String selectedCategory = 'Features'; 
  final List<String> categories = ['Features', 'Updates'];
  
  bool isSending = false;

  Future<void> _generateAndReviewNotification() async {
    Map<String, String> feature;
    String channelId;

    if (selectedCategory == 'Updates') {
      feature = {
        "id": "app_update",
        "name": "App Update",
        "screen": "notes", // generic fallback screen
        "description": "App update available",
        "usage": "Update app"
      };
      channelId = 'channel_updates';
    } else {
      if (selectedFeatureId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a feature first.')),
        );
        return;
      }
      feature = appFeatures.firstWhere((f) => f['id'] == selectedFeatureId);
      channelId = 'channel_features';
    }

    setState(() {
      isSending = true;
    });

    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);

      final response = await http.post(
        Uri.parse('${apiProvider.baseUrl}/admin/generate-feature-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${apiProvider.currentSessionToken}',
        },
        body: jsonEncode({
          'feature_id': feature['id'],
          'feature_name': feature['name'],
          'target_screen': feature['screen'],
          'channel_id': channelId,
          'description': feature['description'],
          'usage': feature['usage'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          _showReviewDialog(data['title'], data['body'], feature, channelId);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${response.body}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void _showReviewDialog(String initialTitle, String initialBody, Map<String, String> feature, String channelId) {
    final titleController = TextEditingController(text: initialTitle);
    final bodyController = TextEditingController(text: initialBody);
    DateTime? selectedDate;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDispatching = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Review Notification'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bodyController,
                      decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate == null ? 'Send Immediately' : 'Scheduled: ${selectedDate!.month}/${selectedDate!.day} ${selectedDate!.hour}:${selectedDate!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setStateDialog(() {
                                  selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                          child: const Text('Schedule'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDispatching ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: isDispatching ? null : () async {
                    setStateDialog(() => isDispatching = true);
                    await _dispatchNotification(
                      titleController.text, 
                      bodyController.text, 
                      feature, 
                      channelId,
                      selectedDate,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: isDispatching 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : Text(selectedDate == null ? 'Send Now' : 'Schedule'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _dispatchNotification(String title, String body, Map<String, String> feature, String channelId, DateTime? scheduledFor) async {
    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      
      final Map<String, dynamic> requestBody = {
        'feature_id': feature['id'],
        'target_screen': feature['screen'],
        'channel_id': channelId,
        'title': title,
        'body': body,
      };
      
      if (scheduledFor != null) {
        requestBody['scheduled_for'] = scheduledFor.toUtc().toIso8601String();
      }

      final response = await http.post(
        Uri.parse('${apiProvider.baseUrl}/admin/dispatch-feature-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${apiProvider.currentSessionToken}',
        },
        body: jsonEncode(requestBody),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Scheduled successfully!")),
          );
          setState(() {
            selectedFeatureId = null;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${response.body}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dispatch: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Send Push Notification'),
        backgroundColor: Colors.deepPurple.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will prompt the AI on the server to generate a notification about the selected feature and broadcast it to all active devices.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            const Text(
              '1. Select Notification Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedCategory = val);
                }
              },
            ),
            const SizedBox(height: 24),
            
            if (selectedCategory == 'Features') ...[
              const Text(
                '2. Select Feature to Highlight',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              isLoadingFeatures
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: selectedFeatureId,
                      hint: const Text('Choose a feature...'),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: appFeatures.map((feature) {
                        return DropdownMenuItem<String>(
                          value: feature['id'],
                          child: Text(feature['name']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedFeatureId = val;
                        });
                      },
                    ),
              const SizedBox(height: 32),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'An AI-generated "App Update Available" notification will be drafted for you to review.',
                style: TextStyle(color: Colors.deepPurple, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 32),
            ],
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSending ? null : _generateAndReviewNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate Notification', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
