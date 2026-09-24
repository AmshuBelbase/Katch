import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // For DashboardShell

class OnboardingContent {
  final String version;
  final String title;
  final String description;
  final IconData iconData;
  final Color color;

  OnboardingContent({
    required this.version,
    required this.title,
    required this.description,
    required this.iconData,
    required this.color,
  });
}

class OnboardingData {
  static final List<OnboardingContent> allFeatures = [
    OnboardingContent(
      version: '1.0.0',
      title: 'Capture Memories',
      description: 'Record voice notes and let AI organize them for you instantly.',
      iconData: Icons.mic,
      color: Colors.blueAccent,
    ),
    OnboardingContent(
      version: '1.0.0',
      title: 'AI Chat',
      description: 'Ask questions about your memories and get instant answers.',
      iconData: Icons.auto_awesome,
      color: Colors.purpleAccent,
    ),
    OnboardingContent(
      version: '1.0.0',
      title: 'Smart Reminders',
      description: 'Never miss an event. The AI extracts reminders automatically from your notes.',
      iconData: Icons.access_time_filled,
      color: Colors.orangeAccent,
    ),
    OnboardingContent(
      version: '1.1.2',
      title: 'Expense Tracking',
      description: 'We now track your transactions and finances seamlessly.',
      iconData: Icons.account_balance_wallet,
      color: Colors.green,
    ),
  ];
}

enum OnboardingMode { full, update }

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({Key? key}) : super(key: key);

  @override
  _OnboardingWrapperState createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _isLoading = true;
  bool _showOnboarding = false;
  OnboardingMode _mode = OnboardingMode.full;
  List<OnboardingContent> _slidesToShow = [];

  @override
  void initState() {
    super.initState();
    _checkOnboardingState();
  }

  // Returns true if v1 > v2
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

  Future<void> _checkOnboardingState() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. "1.1.2"
    
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    
    final hasSeenInitial = metadata['has_seen_initial_onboarding'] ?? false;
    final lastSeenVersion = metadata['last_seen_app_version'] ?? '0.0.0';

    if (!hasSeenInitial) {
      _showOnboarding = true;
      _mode = OnboardingMode.full;
      _slidesToShow = OnboardingData.allFeatures;
    } else if (_isVersionGreater(currentVersion, lastSeenVersion)) {
      // Check for updates
      _slidesToShow = OnboardingData.allFeatures.where((feature) {
        return _isVersionGreater(feature.version, lastSeenVersion) && 
               !_isVersionGreater(feature.version, currentVersion);
      }).toList();

      if (_slidesToShow.isNotEmpty) {
        _showOnboarding = true;
        _mode = OnboardingMode.update;
      } else {
        // No new UI features to show, just update the version silently
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'has_seen_initial_onboarding': true,
              'last_seen_app_version': currentVersion,
            },
          ),
        );
        _showOnboarding = false;
      }
    } else {
      _showOnboarding = false;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        mode: _mode,
        slides: _slidesToShow,
        onComplete: () async {
          final packageInfo = await PackageInfo.fromPlatform();
          
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'has_seen_initial_onboarding': true,
                'last_seen_app_version': packageInfo.version,
              },
            ),
          );
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardShell()),
            );
          }
        },
      );
    }

    return const DashboardShell();
  }
}

class OnboardingScreen extends StatefulWidget {
  final OnboardingMode mode;
  final List<OnboardingContent> slides;
  final VoidCallback onComplete;

  const OnboardingScreen({
    Key? key,
    required this.mode,
    required this.slides,
    required this.onComplete,
  }) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) {
      // Fallback if empty
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onComplete());
      return const Scaffold();
    }
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: const Text('Skip'),
              ),
            ),
            if (widget.mode == OnboardingMode.update)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "What's New in this Update",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _isLastPage = index == widget.slides.length - 1;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = widget.slides[index];
                  return _buildSlideContent(slide);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: widget.slides.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Theme.of(context).colorScheme.primary,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_isLastPage) {
                        widget.onComplete();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(_isLastPage ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSlideContent(OnboardingContent slide) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: slide.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide.iconData,
              size: 100,
              color: slide.color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            slide.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
