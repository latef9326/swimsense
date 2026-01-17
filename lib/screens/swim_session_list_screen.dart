import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../blocs/analytics/analytics_cubit.dart';
import '../blocs/coaching/coaching_cubit.dart';
import '../models/swim_session.dart';
import 'training_detail_screen.dart';

class SwimSessionListScreen extends StatefulWidget {
  const SwimSessionListScreen({super.key});

  @override
  State<SwimSessionListScreen> createState() => _SwimSessionListScreenState();
}

class _SwimSessionListScreenState extends State<SwimSessionListScreen> {
  final Box<SwimSession> sessionBox = Hive.box<SwimSession>('swim_sessions');
  
  // Form controllers for custom session
  late TextEditingController _distanceController;
  late TextEditingController _lapsController;
  late TextEditingController _strokesController;
  late TextEditingController _hrAvgController;
  late TextEditingController _paceController;
  late TextEditingController _durationMinController;

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController();
    _lapsController = TextEditingController();
    _strokesController = TextEditingController();
    _hrAvgController = TextEditingController();
    _paceController = TextEditingController();
    _durationMinController = TextEditingController();
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _lapsController.dispose();
    _strokesController.dispose();
    _hrAvgController.dispose();
    _paceController.dispose();
    _durationMinController.dispose();
    super.dispose();
  }

  void _showAddSessionDialog() {
    // Reset form
    _distanceController.clear();
    _lapsController.clear();
    _strokesController.clear();
    _hrAvgController.clear();
    _paceController.clear();
    _durationMinController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Custom Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Distance (m)',
                    hintText: '1000',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lapsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Laps',
                    hintText: '40',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _strokesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Strokes',
                    hintText: '850',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hrAvgController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Avg Heart Rate (bpm)',
                    hintText: '140',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _paceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pace (min/100m)',
                    hintText: '1.8',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _durationMinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: '60',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _saveCustomSession();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _saveCustomSession() {
    try {
      final distance = double.parse(_distanceController.text);
      final laps = int.parse(_lapsController.text);
      final strokes = int.parse(_strokesController.text);
      final hrAvg = int.parse(_hrAvgController.text);
      final pace = double.parse(_paceController.text);
      final durationMin = int.parse(_durationMinController.text);

      final session = SwimSession()
        ..startTime = DateTime.now().subtract(Duration(minutes: durationMin))
        ..endTime = DateTime.now()
        ..totalStrokes = strokes
        ..distance = distance
        ..elapsedTime = durationMin * 60 // in seconds
        ..averageHeartRate = hrAvg
        ..maxHeartRate = (hrAvg * 1.1).toInt()
        ..averagePace = pace
        ..laps = laps
        ..swimStyle = 'custom'
        ..calories = (durationMin * 7).toInt() // rough estimate
        ..heartRateData = List.generate(60, (i) => (hrAvg - 10 + (i % 20)).toInt());

      sessionBox.add(session);
      
      // Refresh analytics
      context.read<AnalyticsCubit>().loadAnalytics();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session saved and analytics updated'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid input: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearAllSessions() {
    sessionBox.clear();
  }

  void _deleteSession(int index) {
    sessionBox.deleteAt(index);
    // Notify AnalyticsCubit to reload analytics and update Progress Dashboard
      context.read<CoachingCubit>().loadRecommendations();
    context.read<AnalyticsCubit>().loadAnalytics();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session deleted'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearAllSessions,
            tooltip: 'Clear all sessions',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: sessionBox.listenable(),
        builder: (context, Box<SwimSession> box, _) {
          final sessions = box.values.toList();

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pool, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No swim sessions',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first session!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.pool, color: Colors.blue),
                    title: Text(
                      '${session.distance} m',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${session.totalStrokes} strokes • ${_formatDuration(session.elapsedTime)}${session.isPartial ? ' (partial)' : ''}\nHR avg: ${session.averageHeartRate} bpm • Laps: ${session.laps}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String result) {
                        if (result == 'delete') {
                          _deleteSession(index);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Delete Session'),
                            ],
                          ),
                        ),
                      ],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (session.isPartial) const Icon(Icons.warning, color: Colors.orange, size: 16),
                          Text(_formatDate(session.startTime)),
                          Text(session.swimStyle),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingDetailScreen(session: session)));
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSessionDialog,
        tooltip: 'Add custom session',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
