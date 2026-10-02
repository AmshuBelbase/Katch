import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/api_provider.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  // We only need the feature ID and the corresponding deep link screen
  final List<Map<String, String>> appFeatures = [
    {
      "id": "repeating_alarms",
      "name": "Repeating Alarms",
      "screen": "reminders" // Deep link target
    },
    {
      "id": "splitwise_integration",
      "name": "Splitwise Sync",
      "screen": "finance" // Deep link target
    },
    {
      "id": "voice_notes",
      "name": "Voice Notes & Transcription",
      "screen": "notes" // Deep link target
    }
  ];

  String? selectedFeatureId;
  String selectedCategory = 'Features'; 
  final List<String> categories = ['Features', 'Updates', 'Reminders'];
  
  bool isSending = false;

  Future<void> _sendNotificationRequest() async {
    if (selectedFeatureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a feature first.')),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final apiProvider = Provider.of<ApiProvider>(context, listen: false);
      final feature = appFeatures.firstWhere((f) => f['id'] == selectedFeatureId);
      
      // Determine Android Channel ID based on category
      String channelId = 'channel_features';
      if (selectedCategory == 'Updates') channelId = 'channel_updates';
      if (selectedCategory == 'Reminders') channelId = 'channel_reminders';

      final response = await http.post(
        Uri.parse('\${apiProvider.baseUrl}/api/admin/send-feature-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer \${apiProvider.currentSessionToken}', // Ensure only admins can call this
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Success: Sent to \${data['sent_count']} devices!')),
          );
          setState(() {
            selectedFeatureId = null;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: \${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: \$e')),
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
              '1. Select Feature to Highlight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 24),
            
            const Text(
              '2. Select Notification Category',
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
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSending ? null : _sendNotificationRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate & Broadcast (Server-Side)', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
