import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart';
class ApiProvider extends ChangeNotifier {
  Map<String, String> get _headers {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _addAuthToMultipart(http.MultipartRequest request) {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
  }

  // Use 10.0.2.2 for Android emulators, otherwise 127.0.0.1
  String get _localUrl {
    try {
      if (Platform.isAndroid) return "http://10.0.2.2:8000/api";
    } catch (_) {}
    return "http://127.0.0.1:8000/api";
  }
  
  final String _cloudUrl = "https://memappbackend.onrender.com/api";
  
  late String baseUrl = _localUrl; // Default to local backend

  bool isLoading = false;
  String? error;

  List<dynamic> memories = [];
  List<dynamic> reminders = [];
  List<dynamic> transactions = [];
  List<dynamic> chatHistory = [];
  List<dynamic> expenseCategories = [];
  Future<void>? initFuture;
  String connectionStatus = "Initializing Katch...";
  int remainingChats = 15;

  String _getTimezoneOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  ApiProvider() {
    initFuture = _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    _setLoading(true);
    error = null;
    connectionStatus = "Checking server connectivity...";
    notifyListeners();
    
    Future<bool> checkHealth(String url, {int timeoutMs = 5000}) async {
      try {
        final response = await http.get(Uri.parse('$url/health')).timeout(Duration(milliseconds: timeoutMs));
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }

    // Ping cloud first
    bool isCloudAlive = await checkHealth(_cloudUrl, timeoutMs: 5000);
    
    if (isCloudAlive) {
      baseUrl = _cloudUrl;
      connectionStatus = "Connected to cloud server!";
      print("Connected to CLOUD server at $baseUrl");
    } else {
      // If cloud fails, try local
      bool isLocalAlive = await checkHealth(_localUrl, timeoutMs: 800);
      if (isLocalAlive) {
        baseUrl = _localUrl;
        connectionStatus = "Connected to local server!";
        print("Connected to LOCAL server at $baseUrl");
      } else {
        connectionStatus = "Server unreachable.";
        error = "Cannot access server. Please check your internet connection.";
        _setLoading(false);
        notifyListeners();
        throw Exception(error); // Bubble up so dependent API calls stop
      }
    }
    notifyListeners();
    
    // Only fetch data if we have an active auth session
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) {
      connectionStatus = "Syncing your memory vault...";
      notifyListeners();
      await Future.wait([
        _fetchMemoriesInternal(),
        _fetchRemindersInternal(),
        _fetchTransactionsInternal(),
        _fetchExpenseCategoriesInternal(),
        fetchChatStatus(),
      ]);
    }
    _setLoading(false);
  }



  Future<String?> createAudioMemory(String filePath) async {
    await initFuture;
    _setLoading(true);
    Future<String?> attemptUpload() async {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/memory'));
      _addAuthToMultipart(request);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['timezone_offset'] = _getTimezoneOffset();
      
      var response = await request.send().timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        
        if (jsonResponse['memory'] != null) memories.insert(0, jsonResponse['memory']);
        if (jsonResponse['reminders'] != null) reminders.addAll(jsonResponse['reminders']);
        if (jsonResponse['transactions'] != null) transactions.addAll(jsonResponse['transactions']);
        
        _syncAlarms();
        notifyListeners();
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
    await initFuture;
    _setLoading(true);
    await _fetchMemoriesInternal();
    _setLoading(false);
  }

  Future<void> _fetchExpenseCategoriesInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/expense_categories'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        expenseCategories = data['categories'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      print('Failed to fetch expense categories: $e');
    }
  }

  Future<Map<String, dynamic>> addExpenseCategory(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expense_categories'),
        headers: _headers,
        body: json.encode({'name': name}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        expenseCategories.add(data['category']);
        notifyListeners();
        return {'status': 'success'};
      } else {
        return {'status': 'error', 'message': data['detail'] ?? 'Failed to add category'};
      }
    } catch (e) {
      print('Failed to add expense category: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteExpenseCategory(String name) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expense_categories/$name'),
        headers: _headers,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        expenseCategories.removeWhere((c) => c['name'] == name);
        notifyListeners();
        return {'status': 'success'};
      } else {
        return {'status': 'error', 'message': data['detail'] ?? 'Failed to delete category'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<void> _fetchMemoriesInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/memories'), headers: _headers);
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

  Future<Map<String, dynamic>> forceExtractReminder(String memoryId) async {
    await initFuture;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/memories/$memoryId/extract-reminder'),
        headers: _headers,
        body: json.encode({'timezone_offset': _getTimezoneOffset()}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (data['reminders'] != null) {
          reminders.addAll(data['reminders']);
          _syncAlarms();
        }
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> forceExtractFinance(String memoryId) async {
    await initFuture;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/memories/$memoryId/extract-finance'),
        headers: _headers,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        if (data['transactions'] != null) transactions.addAll(data['transactions']);
        notifyListeners();
      }
      return data;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }


  Future<void> registerFcmToken(String token) async {
    await initFuture;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: _headers,
        body: json.encode({'token': token, 'timezone_offset': _getTimezoneOffset()}),
      );
      if (response.statusCode != 200) {
        print('Failed to register FCM token: ${response.body}');
      }
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }

  Future<void> removeFcmToken(String token) async {
    await initFuture;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/fcm-token'),
        headers: _headers,
        body: json.encode({'token': token, 'timezone_offset': _getTimezoneOffset()}),
      );
      if (response.statusCode != 200) {
        print('Failed to remove FCM token: ${response.body}');
      }
    } catch (e) {
      print('Error removing FCM token: $e');
    }
  }

  Future<String?> transcribeAudio(String filePath) async {
    await initFuture;
    _setLoading(true);
    Future<String?> attemptUpload() async {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/transcribe'));
      _addAuthToMultipart(request);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      request.fields['timezone_offset'] = _getTimezoneOffset();
      
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

  Future<String?> createTextMemory(String text, {String source = 'text'}) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/memory/text'),
        headers: _headers,
        body: json.encode({
          'text': text, 
          'source': source,
          'timezone_offset': _getTimezoneOffset()
        }),
      );
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        
        if (jsonResponse['memory'] != null) memories.insert(0, jsonResponse['memory']);
        if (jsonResponse['reminders'] != null) reminders.addAll(jsonResponse['reminders']);
        if (jsonResponse['transactions'] != null) transactions.addAll(jsonResponse['transactions']);
        
        _syncAlarms();
        notifyListeners();
        return jsonResponse['database_id']?.toString();
      }
      error = "Failed to save memory";
      return null;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> requestOTP(String name, String email, String password) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to request OTP');
      }
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to verify OTP');
      }
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateMemory(String id, String newText) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/memory/$id'),
        headers: _headers,
        body: json.encode({
          'text': newText,
          'timezone_offset': _getTimezoneOffset()
        }),
      );
      if (response.statusCode == 200) {
        // Just update the text locally to avoid fetching all memories
        int index = memories.indexWhere((m) => m['id'].toString() == id);
        if (index != -1) memories[index]['raw_text'] = newText;
        notifyListeners();
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

  Future<bool> deleteMemory(String id) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.delete(Uri.parse('$baseUrl/memory/$id'), headers: _headers);
      if (response.statusCode == 200) {
        // The optimistic update already deleted it locally, no need to fetch
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
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/memories'),
        headers: _headers,
        body: json.encode({'ids': ids}),
      );
      if (response.statusCode == 200) {
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
    await initFuture;
    
    // Optimistic UI update
    int index = memories.indexWhere((m) => m['id'].toString() == id);
    if (index != -1) {
      memories[index]['is_starred'] = isStarred;
      notifyListeners();
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/memory/$id/star'),
        headers: _headers,
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
    await initFuture;
    _setLoading(true);
    await _fetchRemindersInternal();
    _setLoading(false);
  }

  Future<void> _fetchRemindersInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/reminders'), headers: _headers);
      if (response.statusCode == 200) {
        reminders = json.decode(response.body);
        _syncAlarms();
      }
    } catch (e) {
      error = e.toString();
    }
  }

  Future<bool> updateReminderSettings(String id, bool isCompleted, String status) async {
    await initFuture;
    
    // Optimistic UI update
    final index = reminders.indexWhere((r) => r['id'].toString() == id);
    bool previousCompleted = false;
    String previousStatus = 'pending';
    
    if (index != -1) {
      previousCompleted = reminders[index]['is_completed'] ?? false;
      previousStatus = reminders[index]['status'] ?? 'pending';
      
      reminders[index]['is_completed'] = isCompleted;
      reminders[index]['status'] = status;
      _syncAlarms();
      notifyListeners();
    }
    
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/reminders/$id'),
        headers: _headers,
        body: json.encode({
          'is_completed': isCompleted,
          'status': status,
          'timezone_offset': _getTimezoneOffset()
        }),
      );
      if (response.statusCode == 200) {
        if (isCompleted && reminders[index]['recurrence_rule'] != null) {
          await _fetchRemindersInternal();
          notifyListeners();
        }
        return true;
      } else {
        // Revert on failure
        if (index != -1) {
          reminders[index]['is_completed'] = previousCompleted;
          reminders[index]['status'] = previousStatus;
          _syncAlarms();
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      // Revert on failure
      if (index != -1) {
        reminders[index]['is_completed'] = previousCompleted;
        reminders[index]['status'] = previousStatus;
        _syncAlarms();
        notifyListeners();
      }
      return false;
    }
  }

  // --- TRANSACTIONS ---
  Future<void> fetchTransactions() async {
    await initFuture;
    _setLoading(true);
    await _fetchTransactionsInternal();
    _setLoading(false);
  }

  Future<void> _fetchTransactionsInternal() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/transactions'), headers: _headers);
      if (response.statusCode == 200) {
        transactions = json.decode(response.body);
      }
    } catch (e) {
      error = e.toString();
    }
  }

  // --- CHAT ---
  Future<void> fetchChatStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/status'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        remainingChats = data['remaining_chats'] ?? 15;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching chat status: $e');
    }
  }

  Future<void> sendChatMessage(String message) async {
    await initFuture;
    chatHistory.add({"sender": "user", "text": message});
    notifyListeners();

    try {
      final offset = Uri.encodeComponent(_getTimezoneOffset());
      final response = await http.get(Uri.parse('$baseUrl/chat?q=${Uri.encodeComponent(message)}&timezone_offset=$offset'), headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        chatHistory.add({"sender": "ai", "text": data['answer']});
        if (data['remaining_chats'] != null) {
          remainingChats = data['remaining_chats'];
        }
      } else {
        chatHistory.add({"sender": "ai", "text": "Sorry, I couldn't process that request."});
      }
    } catch (e) {
      chatHistory.add({"sender": "ai", "text": "Error: Could not reach the server."});
    }
    notifyListeners();
  }

  Future<bool> deleteReminder(String id) async {
    await initFuture;
    _setLoading(true);

    // Optimistically remove from list
    final index = reminders.indexWhere((r) => r['id'].toString() == id);
    Map<String, dynamic>? backup;
    if (index != -1) {
      backup = reminders[index];
      reminders.removeAt(index);
      _syncAlarms();
      notifyListeners();
    }

    try {
      final response = await http.delete(Uri.parse('$baseUrl/reminders/$id'), headers: _headers);
      if (response.statusCode == 200) {
        // success
        return true;
      }
      // Revert on failure
      if (backup != null) {
        reminders.insert(index, backup);
        _syncAlarms();
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (backup != null) {
        reminders.insert(index, backup);
        _syncAlarms();
        notifyListeners();
      }
      error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteTransaction(String id) async {
    await initFuture;
    _setLoading(true);

    // Optimistically remove from list
    final index = transactions.indexWhere((t) => t['id'].toString() == id);
    Map<String, dynamic>? backup;
    if (index != -1) {
      backup = transactions[index];
      transactions.removeAt(index);
      notifyListeners();
    }

    try {
      final response = await http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: _headers);
      if (response.statusCode == 200) {
        // success
        return true;
      }
      if (backup != null) {
        transactions.insert(index, backup);
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (backup != null) {
        transactions.insert(index, backup);
        notifyListeners();
      }
      error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addManualReminder(Map<String, dynamic> data) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reminders/manual'),
        headers: _headers,
        body: json.encode(data)
      );
      if (response.statusCode == 200) {
        await fetchReminders();
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

  Future<bool> addManualTransaction(Map<String, dynamic> data) async {
    await initFuture;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/transactions/manual'),
        headers: _headers,
        body: json.encode(data)
      );
      if (response.statusCode == 200) {
        await fetchTransactions();
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

  // --- HELPER ---
  void hideMemoryOptimistically(String memoryId) {
    memories.removeWhere((m) => m['id'].toString() == memoryId);
    reminders.removeWhere((r) => r['memory_id'].toString() == memoryId);
    transactions.removeWhere((t) => t['memory_id'].toString() == memoryId);
    notifyListeners();
  }

  void hideMultipleMemoriesOptimistically(List<String> memoryIds) {
    memories.removeWhere((m) => memoryIds.contains(m['id'].toString()));
    reminders.removeWhere((r) => memoryIds.contains(r['memory_id'].toString()));
    transactions.removeWhere((t) => memoryIds.contains(t['memory_id'].toString()));
    notifyListeners();
  }

  void hideReminderOptimistically(String id) {
    reminders.removeWhere((r) => r['id'].toString() == id);
    notifyListeners();
  }

  void hideTransactionOptimistically(String id) {
    transactions.removeWhere((t) => t['id'].toString() == id);
    notifyListeners();
  }

  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

  Future<void> _syncAlarms() async {
    final activeAlarms = await Alarm.getAlarms();
    final activeAlarmIds = activeAlarms.map((a) => a.id).toSet();
    final validAlarmIds = <int>{};
    
    for (var r in reminders) {
      if (r['is_completed'] == true) continue;
      
      if (r['status'] == 'phone' || r['status'] == 'both') {
        DateTime dueUtc = DateTime.parse(r['due_datetime']);
        if (!dueUtc.isUtc) dueUtc = DateTime.parse('${r['due_datetime']}Z');
        DateTime dueLocal = dueUtc.toLocal();
        
        if (dueLocal.isAfter(DateTime.now()) && dueLocal.year < 2099) {
          int id = r['id'].toString().hashCode.abs() % 100000;
          validAlarmIds.add(id);
          
          if (!activeAlarmIds.contains(id)) {
            final alarmSettings = AlarmSettings(
              id: id,
              dateTime: dueLocal,
              assetAudioPath: 'assets/alarm.mp3',
              loopAudio: true,
              vibrate: true,
              volumeSettings: VolumeSettings.fade(
                volume: 0.8,
                fadeDuration: const Duration(seconds: 3),
              ),
              notificationSettings: NotificationSettings(
                title: 'Katch Reminder',
                body: r['task_name'] ?? 'Task due!',
              ),
              warningNotificationOnKill: Platform.isIOS,
            );
            await Alarm.set(alarmSettings: alarmSettings);
          }
        }
      }
    }
    
    for (var alarmId in activeAlarmIds) {
      if (!validAlarmIds.contains(alarmId)) {
        await Alarm.stop(alarmId);
      }
    }
  }
}
