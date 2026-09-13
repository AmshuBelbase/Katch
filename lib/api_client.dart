import 'package:http/http.dart' as http;
import 'dart:async';

class ApiClient {
  // Singleton pattern to keep the cached URL across the app
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // The live cloud backend URL (Replace once deployed to Render)
  final String cloudUrl = 'https://memappbackend.onrender.com/api';
  
  // The local laptop backend URL (Uses adb reverse over USB)
  final String localUrl = 'http://127.0.0.1:8000/api';

  String? _cachedWorkingUrl;

  /// Attempts to connect to the cloud server, falling back to the local server.
  /// Throws an exception if both fail.
  Future<String> getWorkingUrl() async {
    // If we've already found a working URL this session, return it quickly
    if (_cachedWorkingUrl != null) {
      return _cachedWorkingUrl!;
    }

    // 1. Try the Local Laptop Backend First (Great for development)
    try {
      print('Attempting to connect to Local Fallback Backend...');
      final response = await http
          .get(Uri.parse('$localUrl/memories'))
          .timeout(const Duration(seconds: 15)); // Increased to 15s
          
      if (response.statusCode == 200) {
        print('Local Fallback Backend Connected!');
        _cachedWorkingUrl = localUrl;
        return localUrl;
      }
    } catch (e) {
      print('Local Backend not reachable: $e');
    }

    // 2. Fallback to the Cloud Backend (When you leave the house)
    try {
      print('Attempting to connect to Cloud Backend...');
      final response = await http
          .get(Uri.parse('$cloudUrl/memories'))
          .timeout(const Duration(seconds: 30)); // Increased to 30s to allow Render to wake up
          
      if (response.statusCode == 200) {
        print('Cloud Backend Connected!');
        _cachedWorkingUrl = cloudUrl;
        return cloudUrl;
      }
    } catch (e) {
      print('Cloud Backend not reachable: $e');
    }

    // 3. Both failed
    throw Exception('Backend not reachable');
  }

  /// Forces the client to check the connection again (useful for pull-to-refresh)
  void resetConnectionCache() {
    _cachedWorkingUrl = null;
  }
}
