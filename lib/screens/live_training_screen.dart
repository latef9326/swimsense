import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/live_training/live_training_cubit.dart';
import '../blocs/live_training/live_training_state.dart';
import '../blocs/ble_connection/ble_connection_cubit.dart';
import '../blocs/user_profile/user_profile_cubit.dart';
import '../blocs/analytics/analytics_cubit.dart';
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
                      
                      // 🔧 Get age from UserProfile (fallback to 30)
                      final userProfileCubit = context.read<UserProfileCubit>();
                      final profileAge = userProfileCubit.state.profile?.age ?? 30;
                      
                      // Calculate max HR based on age
                      final maxHR = 220 - profileAge;
                      final percentMaxHR = hr > 0 ? ((hr / maxHR) * 100).round() : 0;

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
                            children: [
                              SizedBox(
                                width: 140,
                                child: HeartRateIndicator(heartRate: hr, age: profileAge),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: _bigStat('Distance', '${distance.toStringAsFixed(2)} m'),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: _bigStat('Pace', '${pace.toStringAsFixed(2)} min/100m'),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: _bigStat('Max HR', '$percentMaxHR%'),
                                ),
                              ),
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
    if (history.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No speed data yet')),
      );
    }

    // Convert to FlSpot with 2-second intervals
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final item = history[i];
      final timeSeconds = i * 2; // 2-sec intervals
      final speed = (item.speed is double) ? item.speed as double : 0.0;
      spots.add(FlSpot(timeSeconds.toDouble(), speed));
    }

    // Find max speed for better scaling
    final maxSpeed = spots.isEmpty 
      ? 2.0 
      : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    final chartMaxY = (maxSpeed * 1.2).clamp(1.0, 10.0); // Add 20% padding, max 10 m/s

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 1),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: (chartMaxY / 4).ceilToDouble(),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 0.8,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final seconds = value.toInt();
                  return Text(
                    '${seconds}s',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
                interval: (spots.length * 2 / 5).ceilToDouble(), // Show ~5 labels
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  );
                },
                interval: (chartMaxY / 4).ceilToDouble(),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: Colors.blue,
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withValues(alpha: 0.15),
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.blue,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              isStrokeCapRound: true,
            ),
          ],
          maxY: chartMaxY,
          minY: 0,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  return LineTooltipItem(
                    '${barSpot.y.toStringAsFixed(2)} m/s\n${barSpot.x.toStringAsFixed(0)}s',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
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
            ElevatedButton(
              onPressed: isRunning
                  ? () {
                      cubit.recordLap();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lap recorded')));
                    }
                  : null,
              child: const Text('LAP'),
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
