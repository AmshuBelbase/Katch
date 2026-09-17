import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/api_provider.dart';
import 'theme.dart';
import 'screens/add_screen.dart';
import 'screens/memories_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/transactions_screen.dart';

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
    return const DashboardShell();
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

  void _navigateFromMessage(RemoteMessage message) {
    final screen = message.data['screen'];
    if (screen == 'reminders') {
      setState(() => _currentIndex = 3);
    }
    // Add more screen mappings here as needed
  }

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _setupAlarmListener();
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
            content: Text(alarmSettings.notificationBody ?? "A scheduled reminder is due!"),
            actions: [
              TextButton(
                onPressed: () {
                  Alarm.stop(alarmSettings.id);
                  Navigator.pop(context);
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finance',
          ),
        ],
      ),
    );
  }
}