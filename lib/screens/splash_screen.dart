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
  @override
  void initState() {
    super.initState();
    _navigateToNext();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<ApiProvider>(
          builder: (context, api, child) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/katch_animation.gif',
                      height: 180,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.memory,
                          size: 100,
                          color: AppTheme.primary,
                        );
                      },
                    ),
                    const SizedBox(height: 64),
                    LinearProgressIndicator(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      api.connectionStatus,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
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
