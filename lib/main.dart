import 'package:flutter/material.dart';
import 'memory_screen.dart';
import 'search_screen.dart';

void main() {
  runApp(const VoiceMemoryApp());
}

class VoiceMemoryApp extends StatelessWidget {
  const VoiceMemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Memory Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // 1. Update the screen list
  final List<Widget> _screens = [
    const MemoryScreen(),
    const SearchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Memory Hub'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        // 2. Update the icons in the navigation bar
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }
}