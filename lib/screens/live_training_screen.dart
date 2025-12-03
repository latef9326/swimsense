import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/live_training/live_training_cubit.dart';
import '../blocs/live_training/live_training_state.dart';
import '../blocs/ble_connection/ble_connection_cubit.dart';
import '../repositories/swim_session_repository.dart';

class LiveTrainingScreen extends StatefulWidget {
  final BleConnectionCubit bleCubit;

  const LiveTrainingScreen({super.key, required this.bleCubit});

  @override
  State<LiveTrainingScreen> createState() => _LiveTrainingScreenState();
}

class _LiveTrainingScreenState extends State<LiveTrainingScreen> {
  bool _lapPressed = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LiveTrainingCubit(bleCubit: widget.bleCubit, sessionRepo: SwimSessionRepository()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<LiveTrainingCubit, LiveTrainingState>(
            listener: (context, state) {
              if (state.lastAutoSavedPartial != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Postęp treningu zapisany')));
                // clear marker
                context.read<LiveTrainingCubit>().clearLastAutoSaved();
              }
            },
          ),
          BlocListener<BleConnectionCubit, BleConnectionState>(
            listener: (context, bleState) {
              final liveState = context.read<LiveTrainingCubit>().state;
              if (bleState.status != BleStatus.connected && liveState.status == TrainingStatus.paused) {
                final snack = SnackBar(
                  content: const Text('Połączenie BLE utracone - sesja zapisana jako częściowa'),
                  action: SnackBarAction(
                    label: 'Spróbuj ponownie',
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
          appBar: AppBar(title: const Text('Trening - Na żywo')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                    final hr = state.currentData?.heartRate ?? 0;
                    final distance = state.currentData?.distance ?? 0.0;
                    final pace = state.currentData?.pace ?? 0.0;
                    final strokes = state.currentData?.strokes ?? 0;

                    String twoDigits(int n) => n.toString().padLeft(2, '0');
                    final h = state.elapsedTime.inHours;
                    final m = state.elapsedTime.inMinutes % 60;
                    final s = state.elapsedTime.inSeconds % 60;

                    return Column(
                      children: [
                        Text('${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}', style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _bigStat('HR', '$hr bpm'),
                            _bigStat('Dist', '${distance.toStringAsFixed(0)} m'),
                            _bigStat('Pace', '${pace.toStringAsFixed(2)} min/100m'),
                            _bigStat('Strokes', '$strokes'),
                          ],
                        ),
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
                const Spacer(),
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

  Widget _controlButtons() {
    return BlocBuilder<LiveTrainingCubit, LiveTrainingState>(builder: (context, state) {
      final cubit = context.read<LiveTrainingCubit>();
      final isRunning = state.status == TrainingStatus.running;
      final isPaused = state.status == TrainingStatus.paused;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: isRunning ? null : () => cubit.startTraining(),
            child: const Text('START'),
          ),
          ElevatedButton(
            onPressed: isRunning ? () => cubit.pauseTraining() : (isPaused ? () => cubit.resumeTraining() : null),
            child: Text(isRunning ? 'PAUSE' : (isPaused ? 'RESUME' : 'PAUSE')),
          ),
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
          ElevatedButton(
            onPressed: (state.status == TrainingStatus.running || state.status == TrainingStatus.paused) ? () => cubit.stopTraining() : null,
            child: const Text('STOP'),
          ),
        ],
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
}
