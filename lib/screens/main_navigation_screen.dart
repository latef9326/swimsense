import 'package:flutter/material.dart';

import 'ble_connection_screen.dart';
import 'live_training_screen.dart';
import 'swim_session_list_screen.dart';
import 'progress_dashboard_screen.dart';
import 'coaching_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // default to Live Training

  @override
  Widget build(BuildContext context) {
    // ✅ Pages WITHOUT Settings (0-4 only for BottomNavigationBar)
    final pages = <Widget>[
      const BleConnectionScreen(),
      const ProgressDashboardScreen(),
      const LiveTrainingScreen(),
      const SwimSessionListScreen(),
      const CoachingScreen(),
      // Settings is shown when _currentIndex == 5, not in pages list
    ];

    return Scaffold(
      body: SafeArea(
        child: _currentIndex == 5 
          ? const SettingsScreen()  // Show settings when index=5
          : IndexedStack(index: _currentIndex, children: pages),
      ),
      appBar: _currentIndex == 5 ? AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = 2),
        ),
      ) : AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => setState(() => _currentIndex = 5),
            tooltip: 'Settings',
          ),
        ],
      ),
      bottomNavigationBar: _currentIndex == 5 ? null : BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'BLE'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Coach'),
        ],
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
