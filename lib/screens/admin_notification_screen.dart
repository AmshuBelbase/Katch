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
      "id": "voice_notes",
      "name": "Voice Notes & Transcription",
      "screen": "notes",
      "description": "Record voice memos which are instantly transcribed into highly accurate text using AI. The voice recording won't be saved in user's phone or server. Only the transcript will be saved.",
      "usage": "Tap the large microphone icon on the Add/Home screen to start recording your voice note. The AI will transcribe and save it."
    },
    {
      "id": "text_notes",
      "name": "Text Notes",
      "screen": "notes",
      "description": "Type out your thoughts, lists, or memories manually if you don't want to use voice.",
      "usage": "Go to the Add/Home screen and tap the text/pencil icon next to the microphone to open the text input area."
    },
    {
      "id": "smart_reminders",
      "name": "Smart Reminders Extraction",
      "screen": "reminders",
      "description": "The AI automatically detects when you mention a task or deadline in your note and creates a reminder for you.",
      "usage": "Just mention a time or date in your note (e.g., 'Remind me to call John tomorrow at 5 PM'). Check the Reminders tab to see it."
    },
    {
      "id": "smart_transactions",
      "name": "Smart Transactions Extraction",
      "screen": "finance",
      "description": "The AI automatically detects expenses or transactions mentioned in your notes and categorizes them.",
      "usage": "Say or type an expense like 'I spent Rs100 on lunch today'. Check the Finance tab to see your tracked expenses."
    },
    {
      "id": "edit_note",
      "name": "Editing & Resyncing Notes",
      "screen": "memories",
      "description": "Edit the text of any past note. The AI will intelligently resync, deleting old auto-extracted reminders or transactions and creating new ones based on the updated text.",
      "usage": "Go to the Notes screen, tap the three dots on any note, select 'Edit', and update your text."
    },
    {
      "id": "chat_with_memories",
      "name": "Chat with Memories",
      "screen": "chat",
      "description": "Ask our AI assistant questions about your past notes, expenses, or reminders, and it will search your history to answer.",
      "usage": "Go to the AI Chat screen and ask questions like 'How much did I spend on food this month?' or 'When is my flight?'."
    },
    {
      "id": "app_widget",
      "name": "App Widget (Home Screen)",
      "screen": "notes",
      "description": "Add the Katch widget directly to your phone's home screen for quick 1-tap access to voice recording.",
      "usage": "Long press on your phone's home screen, tap 'Widgets', find Katch widget you like, and drag it to your screen."
    },
    {
      "id": "repeating_alarms",
      "name": "Repeating Alarms",
      "screen": "reminders",
      "description": "Set alarms that ring daily, weekly, or on specific days/time for recurring or one-off tasks by just mentioning it on Note you save. (AI reads and extracts the task and reminder)",
      "usage": "Simply save a voice or text note mentioning your repeating schedule or one-off task (e.g., 'Remind me to take my medicine every day at 8 AM' or 'Remind me to call John tomorrow at 5 PM'). The AI will automatically set up the recurring alarm and notification for you."
    },
    {
      "id": "splitwise_integration",
      "name": "Splitwise (Borrowing/Lending)",
      "screen": "finance",
      "description": "Automatically identifies and tracks borrowing or lending transactions based on your voice or text notes, acting as a built-in expense splitter.",
      "usage": "Simply mention when you borrow from or lend money to someone in a note (e.g., 'John paid Rs100 for my lunch'). You can view all balances ('You owe' / 'Owed to you') in the Splitwise tab of the Finance screen."
    },
    {
      "id": "daily_drops",
      "name": "Daily Drops",
      "screen": "reminders",
      "description": "Receive a daily push notification summarizing your upcoming tasks and recent transactions.",
      "usage": "This happens automatically in the background every morning to keep you updated on your day."
    },

    {
      "id": "expense_categories",
      "name": "Custom Expense Categories",
      "screen": "finance",
      "description": "Create custom categories for your expenses to better organize and track your spending. Creating/Deleting a category will reorganize your transactions to better categorise them!",
      "usage": "Go to the Finance tab, tap the + Category button, and manage your categories there. You won't be able to delete the default categories. You can only add/delete your custom categories."
    },
    {
      "id": "star_notes",
      "name": "Star & Favorite Notes",
      "screen": "memories",
      "description": "Bookmark your most important notes so you can easily find them later using the star filter.",
      "usage": "Go to the Notes screen and tap the Star icon on any note. Use the filter chip at the top to view only starred notes."
    },
    {
      "id": "search_notes",
      "name": "Search Notes",
      "screen": "memories",
      "description": "Quickly find specific notes by searching for keywords or phrases.",
      "usage": "Use the search bar at the top of the Memories tab to find what you're looking for."
    }
  ];

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
