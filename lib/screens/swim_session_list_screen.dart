import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/swim_session.dart';
import 'training_detail_screen.dart';

class SwimSessionListScreen extends StatefulWidget {
  const SwimSessionListScreen({super.key});

  @override
  State<SwimSessionListScreen> createState() => _SwimSessionListScreenState();
}

class _SwimSessionListScreenState extends State<SwimSessionListScreen> {
  final Box<SwimSession> sessionBox = Hive.box<SwimSession>('swim_sessions');

  void _addSampleSession() {
    final session = SwimSession()
      ..startTime = DateTime.now().subtract(const Duration(hours: 1))
      ..endTime = DateTime.now()
      ..totalStrokes = 850
      ..distance = 1000.0
      ..elapsedTime = 3600 // 1 hour in seconds
      ..averageHeartRate = 142
      ..maxHeartRate = 156
      ..averagePace = 1.8
      ..laps = 40
      ..swimStyle = 'freestyle'
      ..calories = 420
      ..heartRateData = List.generate(40, (i) => 120 + (i % 10));

    sessionBox.add(session);
  }

  void _clearAllSessions() {
    sessionBox.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SwimSense - Twoje Sesje'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearAllSessions,
            tooltip: 'Wyczyść wszystkie sesje',
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

          return ListView.builder(
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
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (session.isPartial) const Icon(Icons.warning, color: Colors.orange, size: 16),
                      Text(_formatDate(session.startTime)),
                      Text(session.swimStyle),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrainingDetailScreen(session: session)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSampleSession,
        tooltip: 'Dodaj przykładową sesję',
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
