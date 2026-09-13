import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiProvider extends ChangeNotifier {
  String baseUrl = "http://127.0.0.1:8000/api";
  final String _localUrl = "http://127.0.0.1:8000/api";
  final String _cloudUrl = "https://memappbackend.onrender.com/api";

  bool isLoading = false;
  String? error;

  List<dynamic> memories = [];
  List<dynamic> reminders = [];
  List<dynamic> transactions = [];
  List<dynamic> chatHistory = [];
  List<dynamic> expenseCategories = [];
  Future<void>? _initFuture;

  ApiProvider() {
    _initFuture = _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    _setLoading(true);
    try {
      // Ping local server to see if it's running
      final response = await http.get(Uri.parse('$_localUrl/memories')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        baseUrl = _localUrl;
      } else {
        baseUrl = _cloudUrl;
      }
    } catch (_) {
      // Local server is offline or unreachable, fallback to cloud
      baseUrl = _cloudUrl;
    }
    
    // Now fetch all data using the determined baseUrl
    await Future.wait([
      _fetchMemoriesInternal(),
      _fetchRemindersInternal(),
      _fetchTransactionsInternal(),
      _fetchExpenseCategoriesInternal(),
    ]);
    _setLoading(false);
  }



  Future<String?> createAudioMemory(String filePath) async {
    await _initFuture;
    _setLoading(true);
    Future<String?> attemptUpload() async {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/memory'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        await fetchMemories();
        return jsonResponse['saved_text'] ?? jsonResponse['transcription'];
      }
      error = "Failed to upload audio (HTTP ${response.statusCode})";
      return null;
    }

    try {
      String? result = await attemptUpload();
      if (result != null) return result;
    } catch (e) {
      if (baseUrl == _localUrl) {
        print('Local audio upload failed, falling back to cloud: $e');
        baseUrl = _cloudUrl;
        try {
          return await attemptUpload();
        } catch (e2) {
          error = e2.toString();
          return null;
        }
      }
      error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // --- MEMORIES ---
  Future<void> fetchMemories() async {
    await _initFuture;
    _setLoading(true);
    await _fetchMemoriesInternal();
    _setLoading(false);
  }

  Future<void> _fetchExpenseCategoriesInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/expense_categories'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        expenseCategories = data['categories'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      print('Failed to fetch expense categories: $e');
    }
  }

  Future<void> addExpenseCategory(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expense_categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        expenseCategories.add(data['category']);
        notifyListeners();
      }
    } catch (e) {
      print('Failed to add expense category: $e');
    }
  }

  Future<void> _fetchMemoriesInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/memories'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        memories = data['results'] ?? [];
      } else {
        error = "Failed to load memories";
      }
    } catch (e) {
      error = e.toString();
    }
  }

  Future<String?> transcribeAudio(String filePath) async {
    await _initFuture;
    _setLoading(true);
    Future<String?> attemptUpload() async {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        return jsonResponse['transcription'];
      }
      error = "Failed to transcribe audio (HTTP ${response.statusCode})";
      return null;
    }

    try {
      String? result = await attemptUpload();
      if (result != null) return result;
    } catch (e) {
      if (baseUrl == _localUrl) {
        print('Local transcription failed, falling back to cloud: $e');
        baseUrl = _cloudUrl;
        try {
          return await attemptUpload();
        } catch (e2) {
          error = e2.toString();
          return null;
        }
      }
      error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
    return null;
  }

  Future<bool> createTextMemory(String text, {String source = 'text'}) async {
    await _initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/memory/text'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text, 'source': source}),
      );
      if (response.statusCode == 200) {
        await fetchMemories(); // Refresh list
        return true;
      }
      error = "Failed to save memory";
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteMemory(String id) async {
    await _initFuture;
    _setLoading(true);
    try {
      final response = await http.delete(Uri.parse('$baseUrl/memory/$id'));
      if (response.statusCode == 200) {
        await fetchMemories();
        return true;
      }
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteMultipleMemories(List<String> ids) async {
    await _initFuture;
    _setLoading(true);
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/memories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': ids}),
      );
      if (response.statusCode == 200) {
        await fetchMemories();
        return true;
      }
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> toggleStarMemory(String id, bool isStarred) async {
    await _initFuture;
    
    // Optimistic UI update
    int index = memories.indexWhere((m) => m['id'].toString() == id);
    if (index != -1) {
      memories[index]['is_starred'] = isStarred;
      notifyListeners();
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/memory/$id/star'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_starred': isStarred}),
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        // Revert on failure
        if (index != -1) {
          memories[index]['is_starred'] = !isStarred;
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      error = e.toString();
      // Revert on failure
      if (index != -1) {
        memories[index]['is_starred'] = !isStarred;
        notifyListeners();
      }
      return false;
    }
  }

  // --- REMINDERS ---
  Future<void> fetchReminders() async {
    await _initFuture;
    _setLoading(true);
    await _fetchRemindersInternal();
    _setLoading(false);
  }

  Future<void> _fetchRemindersInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/reminders'));
      if (response.statusCode == 200) {
        reminders = json.decode(response.body);
      }
    } catch (e) {
      error = e.toString();
    }
  }

  Future<bool> updateReminderSettings(String id, bool isCompleted, String status) async {
    await _initFuture;
    
    // Optimistic UI update
    final index = reminders.indexWhere((r) => r['id'].toString() == id);
    bool previousCompleted = false;
    String previousStatus = 'pending';
    
    if (index != -1) {
      previousCompleted = reminders[index]['is_completed'] ?? false;
      previousStatus = reminders[index]['status'] ?? 'pending';
      
      reminders[index]['is_completed'] = isCompleted;
      reminders[index]['status'] = status;
      notifyListeners();
    }
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/reminders/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'is_completed': isCompleted,
          'status': status
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        // Revert on failure
        if (index != -1) {
          reminders[index]['is_completed'] = previousCompleted;
          reminders[index]['status'] = previousStatus;
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      // Revert on failure
      if (index != -1) {
        reminders[index]['is_completed'] = previousCompleted;
        reminders[index]['status'] = previousStatus;
        notifyListeners();
      }
      return false;
    }
  }

  // --- TRANSACTIONS ---
  Future<void> fetchTransactions() async {
    await _initFuture;
    _setLoading(true);
    await _fetchTransactionsInternal();
    _setLoading(false);
  }

  Future<void> _fetchTransactionsInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/transactions'));
      if (response.statusCode == 200) {
        transactions = json.decode(response.body);
      }
    } catch (e) {
      error = e.toString();
    }
  }

  // --- CHAT ---
  Future<void> sendChatMessage(String message) async {
    await _initFuture;
    chatHistory.add({"sender": "user", "text": message});
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl/chat?q=${Uri.encodeComponent(message)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        chatHistory.add({"sender": "ai", "text": data['answer']});
      } else {
        chatHistory.add({"sender": "ai", "text": "Sorry, I couldn't process that request."});
      }
    } catch (e) {
      chatHistory.add({"sender": "ai", "text": "Error: Could not reach the server."});
    }
    notifyListeners();
  }

  // --- HELPER ---
  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }
}
