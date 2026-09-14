import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/api_provider.dart';
import '../theme.dart';
import '../main.dart'; // For AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _statusIndex = 0;
  Timer? _timer;
  final List<String> _loadingTexts = [
    'Connecting to server...',
    'Waking up AI...',
    'Syncing notes...',
    'Preparing your workspace...',
    'Initializing KATCH...'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _loadingTexts.length;
        });
      }
    });
    _navigateToNext();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    final apiProvider = Provider.of<ApiProvider>(context, listen: false);
    
    // Wait for the API provider's initialization future to complete
    try {
      if (apiProvider.initFuture != null) {
        await apiProvider.initFuture;
      }
    } catch (e) {
      // Even if there's an error (e.g. server unreachable), we can still proceed
      // to AuthWrapper. The ApiProvider will hold the error state and handle it appropriately.
    }
    
    // Add a tiny artificial delay so the user can see the final "Connected!" or error text
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<ApiProvider>(
          builder: (context, api, child) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          isDark ? 'assets/katch_logo_dark.png' : 'assets/katch_logo_light.png',
                          height: 80,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.notes,
                              size: 60,
                              color: Theme.of(context).colorScheme.onBackground,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'KATCH',
                          style: GoogleFonts.michroma(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 64),
                    LinearProgressIndicator(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        _loadingTexts[_statusIndex],
                        key: ValueKey<int>(_statusIndex),
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
