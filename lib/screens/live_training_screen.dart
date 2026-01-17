import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/live_training/live_training_cubit.dart';
import '../blocs/live_training/live_training_state.dart';
import '../blocs/ble_connection/ble_connection_cubit.dart';
import '../blocs/analytics/analytics_cubit.dart';
import '../repositories/swim_session_repository.dart';
import '../widgets/heart_rate_indicator.dart';
import 'package:fl_chart/fl_chart.dart';

class LiveTrainingScreen extends StatefulWidget {
  // ✅ No need to pass bleCubit - it's available via context.read() from main.dart
  const LiveTrainingScreen({super.key});

  @override
  State<LiveTrainingScreen> createState() => _LiveTrainingScreenState();
}

class _LiveTrainingScreenState extends State<LiveTrainingScreen> {
  bool _lapPressed = false;

  @override
  Widget build(BuildContext context) {
    // ✅ IMPORTANT: Use the LiveTrainingCubit created in main.dart, NOT create a new one!
    // The HR callback in BleConnectionCubit is configured to use that specific instance
    return MultiBlocListener(
      listeners: [
          BlocListener<LiveTrainingCubit, LiveTrainingState>(
            listener: (context, state) {
              if (state.status == TrainingStatus.finished) {
                // Refresh analytics when session is saved
                context.read<AnalyticsCubit>().loadAnalytics();
              }
              if (state.lastAutoSavedPartial != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Training progress saved')));
                // clear marker
                context.read<LiveTrainingCubit>().clearLastAutoSaved();
              }
            },
          ),
          BlocListener<BleConnectionCubit, BleConnectionState>(
            listener: (context, bleState) {
              final liveState = context.read<LiveTrainingCubit>().state;
              
              // ✅ AUTO-START training when BLE connects
              if (bleState.status == BleStatus.connected && liveState.status == TrainingStatus.notStarted) {
                debugPrint('🚀 BLE connected - auto-starting training');
                context.read<LiveTrainingCubit>().startTraining();
              }
              
              if (bleState.status != BleStatus.connected && liveState.status == TrainingStatus.paused) {
                final snack = SnackBar(
                  content: const Text('BLE connection lost - session saved as partial'),
                  action: SnackBarAction(
                    label: 'Retry',
                    onPressed: () {
                      if (bleState.deviceId != null) {
                        context.read<BleConnectionCubit>().connect(bleState.deviceId!, bleState.deviceName ?? '');
                      }
                    },
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(snack);
              }
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(title: const Text('Live Training')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ✅ Device out of range warning
                  BlocBuilder<BleConnectionCubit, BleConnectionState>(
                    builder: (context, bleState) {
                      if (bleState.status == BleStatus.reconnecting || 
                          bleState.status == BleStatus.error) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            border: Border.all(color: Colors.orange.shade700, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bleState.status == BleStatus.reconnecting 
                                          ? '📡 Device out of range - reconnecting...'
                                          : '❌ Device disconnected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                    if (bleState.errorMessage != null)
                                      Text(
                                        bleState.errorMessage!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 8),
                  // Pool length selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Pool:'),
                      const SizedBox(width: 8),
                      BlocBuilder<LiveTrainingCubit, LiveTrainingState>(builder: (context, state) {
                        return DropdownButton<int>(
                          value: state.poolLengthMeters,
                          items: const [
                            DropdownMenuItem(value: 25, child: Text('25 m')),
                            DropdownMenuItem(value: 50, child: Text('50 m')),
                          ],
                          onChanged: (v) {
                            if (v != null) context.read<LiveTrainingCubit>().setPoolLength(v);
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<LiveTrainingCubit, LiveTrainingState>(
                    builder: (context, state) {
                      // 🎯 LOG #3: UI obserwuje zmiany
                      debugPrint('🏗️ BlocBuilder rebuild - HR: ${state.currentData?.heartRate ?? 0} bpm, status: ${state.status}');
                      
                      final hr = state.currentData?.heartRate ?? 0;
                      final distance = state.currentData?.distance ?? 0.0;
                      final pace = state.currentData?.pace ?? 0.0;
                      final strokes = state.currentData?.strokes ?? 0;

                      // prefer millisecond-precision if available
                      final elapsedMs = state.elapsedTimeMillis > 0 ? state.elapsedTimeMillis : state.elapsedTime.inMilliseconds;

                      return Column(
                        children: [
                          Text(
                            _formatTimeWithHundredths(elapsedMs),
                            style: const TextStyle(fontSize: 48, fontFamily: 'RobotoMono'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              HeartRateIndicator(heartRate: hr, age: 30),
                              _bigStat('Dist', '${distance.toStringAsFixed(0)} m'),
                              _bigStat('Pace', '${pace.toStringAsFixed(2)} min/100m'),
                              _bigStat('Strokes', '$strokes'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Live speed chart
                          _buildSpeedChart(state.dataHistory),
                          const SizedBox(height: 12),
                          // Laps summary
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Laps: ${state.lapCount}'),
                                      Row(children: [
                                        Text('Current: ${_formatDurationShort(state.currentLapTime)}'),
                                        const SizedBox(width: 12),
                                        TextButton(onPressed: () => context.read<LiveTrainingCubit>().clearLaps(), child: const Text('Clear')),
                                      ])
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 80,
                                    child: ListView.builder(
                                      itemCount: state.lapDurations.length,
                                      itemBuilder: (ctx, idx) {
                                        final d = state.lapDurations[idx];
                                        return Text('Lap ${idx + 1}: ${_formatDurationPrecise(d)}');
                                      },
                                    ),
                                  )
                              ],
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _controlButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Live speed chart (m/s)
  Widget _buildSpeedChart(List<dynamic> history) {
    // history is a list of TrainingData objects
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final item = history[i];
      final time = i * 2; // approximate x value (seconds)
      final speed = (item.speed is double) ? item.speed as double : 0.0;
      spots.add(FlSpot(time.toDouble(), speed));
    }

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
              dotData: FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButtons() {
    return BlocBuilder<LiveTrainingCubit, LiveTrainingState>(builder: (context, state) {
      final cubit = context.read<LiveTrainingCubit>();
      final isRunning = state.status == TrainingStatus.running;
      final isPaused = state.status == TrainingStatus.paused;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isRunning ? null : () => cubit.startTraining(),
              child: const Text('START'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isRunning ? () => cubit.pauseTraining() : (isPaused ? () => cubit.resumeTraining() : null),
              child: Text(isRunning ? 'PAUSE' : (isPaused ? 'RESUME' : 'PAUSE')),
            ),
            const SizedBox(width: 8),
            // LAP button
            AnimatedScale(
            scale: _lapPressed ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: ElevatedButton(
              onPressed: isRunning
                  ? () {
                      setState(() {
                        _lapPressed = true;
                      });
                      Future.delayed(const Duration(milliseconds: 250), () {
                        setState(() {
                          _lapPressed = false;
                        });
                      });
                      cubit.recordLap();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lap recorded')));
                    }
                  : null,
              child: const Text('LAP'),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (state.status == TrainingStatus.running || state.status == TrainingStatus.paused) ? () => cubit.stopTraining() : null,
            child: const Text('STOP'),
          ),
        ],
      ),
        );
    });
  }

  String _formatDurationShort(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDurationPrecise(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = (d.inMilliseconds % 1000) ~/ 10; // centiseconds
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    final cs = ms.toString().padLeft(2, '0');
    return '$mm:$ss.$cs';
  }

  String _formatTimeWithHundredths(int milliseconds) {
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds % 3600000) ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    final hundredths = (milliseconds % 1000) ~/ 10;
    return '${hours.toString().padLeft(2, '0')}'
        ':${minutes.toString().padLeft(2, '0')}'
        ':${seconds.toString().padLeft(2, '0')}'
        '.${hundredths.toString().padLeft(2, '0')}';
  }
}
