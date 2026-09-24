import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;
  final VoidCallback? onNextOverride;
  final VoidCallback? onPrevOverride;
  final bool isLast;

  const CustomShowcase({
    Key? key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
    this.onNextOverride,
    this.onPrevOverride,
    this.isLast = false,
  }) : super(key: key);

  Future<void> _skipForever() async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'has_seen_initial_onboarding': true}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Showcase.withWidget(
      key: showcaseKey,
      container: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    ShowCaseWidget.of(context).dismiss();
                  },
                  child: const Text('Skip for now', style: TextStyle(color: Colors.grey)),
                ),
                Row(
                  children: [
                    if (onPrevOverride != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onPrevOverride,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => ShowCaseWidget.of(context).previous(),
                      ),
                    ElevatedButton(
                      onPressed: onNextOverride ?? () => ShowCaseWidget.of(context).next(),
                      child: Text(isLast ? 'Got it!' : 'Next'),
                    ),
                  ],
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  _skipForever();
                  ShowCaseWidget.of(context).dismiss();
                },
                child: const Text('Never show again', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}
