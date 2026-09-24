import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart' hide NotificationSettings;
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/api_provider.dart';
import 'theme.dart';
import 'screens/add_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/transactions_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:showcaseview/showcaseview.dart';
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Alarm package
  await Alarm.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://kbupfvxvouitjxvnahib.supabase.co',
    anonKey: 'sb_publishable_quJjzs1OVa9vrotBfkwQ9Q_UPepLczW',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiProvider()),
      ],
      child: const VoiceMemoryApp(),
    ),
  );
}



class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const AuthScreen();
    }
    return ShowCaseWidget(
      onFinish: () async {
        final packageInfo = await PackageInfo.fromPlatform();
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {
            'has_seen_initial_onboarding': true,
            'last_seen_app_version': packageInfo.version,
          }),
        );
      },
      builder: (context) => const DashboardShell(),
    );
  }
}

class VoiceMemoryApp extends StatelessWidget {
  const VoiceMemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Katch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _remindersKey = GlobalKey();
  final GlobalKey _financeKey = GlobalKey();

  void _navigateFromMessage(RemoteMessage message) {
    final screen = message.data['screen'];
    if (screen == 'reminders') {
      setState(() => _currentIndex = 3);
    } else if (screen == 'daily_drop') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    message.data['title'] ?? 'Daily Drop',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message.data['content'] ?? 'Your day is ready!',
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text("Let's Go!", style: TextStyle(fontSize: 16)),
                  )
                ],
              ),
            ),
          ),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _setupAlarmListener();
    _checkOnboarding();
  }

  bool _isVersionGreater(String v1, String v2) {
    List<int> p1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> p2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      int p1Val = i < p1.length ? p1[i] : 0;
      int p2Val = i < p2.length ? p2[i] : 0;
      if (p1Val > p2Val) return true;
      if (p1Val < p2Val) return false;
    }
    return false;
  }

  Future<void> _checkOnboarding() async {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final hasSeenInitial = metadata['has_seen_initial_onboarding'] ?? false;
    final lastSeenVersion = metadata['last_seen_app_version'] ?? '0.0.0';
    
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!hasSeenInitial) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          ShowCaseWidget.of(context).startShowCase([_addKey, _notesKey, _chatKey, _remindersKey, _financeKey]);
        }
      });
    } else if (_isVersionGreater(currentVersion, lastSeenVersion)) {
      if (_isVersionGreater("1.1.2", lastSeenVersion)) {
         Future.delayed(const Duration(milliseconds: 600), () {
           if (mounted) {
             ShowCaseWidget.of(context).startShowCase([_financeKey]);
           }
         });
      } else {
         Supabase.instance.client.auth.updateUser(
           UserAttributes(data: {'last_seen_app_version': currentVersion}),
         );
      }
    }
  }

  void _setupAlarmListener() {
    Alarm.ringStream.stream.listen((alarmSettings) {
      print("Alarm ringing: ${alarmSettings.id}");
      if (mounted) {
        setState(() => _currentIndex = 3);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Alarm Ringing!"),
            content: Text(alarmSettings.notificationSettings.body.isNotEmpty ? alarmSettings.notificationSettings.body : "A scheduled reminder is due!"),
            actions: [
              TextButton(
                onPressed: () async {
                  await Alarm.stop(alarmSettings.id);
                  Navigator.pop(context);
                  
                  // Find the reminder ID associated with this local alarm ID
                  final apiProvider = Provider.of<ApiProvider>(context, listen: false);
                  String? reminderId;
                  for (var r in apiProvider.reminders) {
                    if (r['id'].toString().hashCode.abs() % 100000 == alarmSettings.id) {
                      reminderId = r['id'];
                      break;
                    }
                  }
                  
                  if (reminderId != null) {
                    // Find the existing status to pass to updateReminderSettings
                    String existingStatus = 'pending';
                    for (var r in apiProvider.reminders) {
                      if (r['id'] == reminderId) {
                        existingStatus = r['status'] ?? 'pending';
                        break;
                      }
                    }
                    await apiProvider.updateReminderSettings(reminderId, true, existingStatus);
                  }
                },
                child: const Text("Stop Alarm"),
              )
            ],
          ),
        );
      }
    });
  }

  Future<void> _setupFCM() async {
    // Request permission (mostly for iOS, but good practice)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for notifications');
      // Get the token
      String? token = await messaging.getToken();
      if (token != null) {
        if (mounted) {
          Provider.of<ApiProvider>(context, listen: false).registerFcmToken(token);
        }
      }
    }

    // App opened from a notification while in the BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateFromMessage(message);
    });

    // App opened from a notification while TERMINATED (cold start)
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // Slight delay to ensure the widget tree is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateFromMessage(initialMessage);
      });
    }
  }

  final List<Widget> _screens = [
    const AddScreen(),
    const MemoriesScreen(),
    const ChatScreen(),
    const RemindersScreen(),
    const TransactionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          Showcase(
            key: _addKey,
            title: 'Add Memory',
            description: 'Record voice or type text here.',
            child: const NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Add',
            ),
          ),
          Showcase(
            key: _notesKey,
            title: 'Notes',
            description: 'All your organized memories live here.',
            child: const NavigationDestination(
              icon: Icon(Icons.view_agenda_outlined),
              selectedIcon: Icon(Icons.view_agenda),
              label: 'Notes',
            ),
          ),
          Showcase(
            key: _chatKey,
            title: 'AI Chat',
            description: 'Ask anything about your past notes.',
            child: const NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI Chat',
            ),
          ),
          Showcase(
            key: _remindersKey,
            title: 'Reminders',
            description: 'Tasks and events extracted automatically.',
            child: const NavigationDestination(
              icon: Icon(Icons.access_time),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'Reminders',
            ),
          ),
          Showcase(
            key: _financeKey,
            title: 'Finance',
            description: 'Track expenses and splits seamlessly.',
            child: const NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Finance',
            ),
          ),
        ],
      ),
    );
  }
}