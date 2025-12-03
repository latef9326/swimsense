import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'ble_connection_screen.dart';
import 'live_training_screen.dart';
import 'swim_session_list_screen.dart';
import '../blocs/ble_connection/ble_connection_cubit.dart';
import 'progress_dashboard_screen.dart';
import 'coaching_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // default to Live Training

  @override
  Widget build(BuildContext context) {
    final bleCubit = context.read<BleConnectionCubit>();

    final pages = <Widget>[
      const BleConnectionScreen(),
      const ProgressDashboardScreen(),
      LiveTrainingScreen(bleCubit: bleCubit),
      const SwimSessionListScreen(),
      const CoachingScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
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
