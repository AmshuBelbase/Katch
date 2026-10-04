import 'package:supabase_flutter/supabase_flutter.dart';

class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  Future<void> logEvent(String actionType, {Map<String, dynamic>? content}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Cannot log without authenticated user

    // Delay the network initialization by 500ms so it doesn't interrupt 
    // the 300ms UI screen transition animations.
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await Supabase.instance.client.from('audit_logs').insert({
          'user_id': user.id,
          'action_performed': actionType,
          'content': content ?? {},
          'version': 1,
        });
      } catch (e) {
        print('AuditService failed to log $actionType: $e');
      }
    });
  }

  Future<void> logAppLaunch() async {
    await logEvent('APP_LAUNCH', content: {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'platform': 'flutter',
    });
  }

  Future<void> logScreenSwitch(String source, String destination) async {
    await logEvent('SCREEN_SWITCH', content: {
      'source': source,
      'destination': destination,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
