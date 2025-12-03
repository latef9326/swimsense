import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble_connection/ble_connection_cubit.dart';
import '../../repositories/swim_session_repository.dart';
import '../../models/swim_session.dart';
import '../../repositories/ble_repository.dart';
import 'live_training_state.dart';

class LiveTrainingCubit extends Cubit<LiveTrainingState> {
  final BleConnectionCubit bleCubit;
  final SwimSessionRepository sessionRepo;

  Timer? _timer;
  StreamSubscription? _bleStateSub;
  DateTime? _startTime;

  LiveTrainingCubit({required this.bleCubit, required this.sessionRepo}) : super(LiveTrainingState());

  void startTraining() {
    if (state.status == TrainingStatus.running) return;

    _startTime = DateTime.now();
    emit(LiveTrainingState(status: TrainingStatus.running, elapsedTime: Duration.zero, dataHistory: [], lapTimesMillis: [], lastLapStartElapsedMs: 0));

    // Timer increments elapsedTime every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsedTime: state.elapsedTime + const Duration(seconds: 1)));
    });

    // Subscribe to BLE cubit stream for live TrainingData and connection status
    _bleStateSub = bleCubit.stream.listen((bleState) async {
      // If BLE got disconnected while training, pause and auto-save partial session
      if (bleState.status != BleStatus.connected && state.status == TrainingStatus.running) {
        pauseTraining();
        await _autoSavePartialSession();
        return;
      }

      final last = bleState.lastData;

      // Validate data: ignore obviously impossible values
      if (last != null) {
        if (!_isValidTrainingData(last)) return;

        if (state.status == TrainingStatus.running) {
          final newHistory = List<TrainingData>.from(state.dataHistory)..add(last);
          // automatic lap detection if enabled
          if (state.autoLapEnabled) {
            final lapsSoFar = state.lapTimesMillis.length;
            final nextLapDistance = (lapsSoFar + 1) * state.poolLengthMeters.toDouble();
            if (last.distance >= nextLapDistance) {
              _recordAutoLap();
            }
          }

          emit(state.copyWith(currentData: last, dataHistory: newHistory));
        }
      }
    });
  }

  /// User pressed the lap button. Record lap time and update distance/lap count.
  void recordLap() {
    if (state.status != TrainingStatus.running) return;

    final lapDurationMs = state.elapsedTime.inMilliseconds - state.lastLapStartElapsedMs;
    final newLapTimes = List<int>.from(state.lapTimesMillis)..add(lapDurationMs);
    final newLastLapStart = state.elapsedTime.inMilliseconds;
    emit(state.copyWith(
      lapTimesMillis: newLapTimes,
      lastLapStartElapsedMs: newLastLapStart,
      // keep other fields
    ));
  }

  void setPoolLength(int meters) {
    emit(state.copyWith(poolLengthMeters: meters));
  }

  void clearLaps() {
    emit(state.copyWith(lapTimesMillis: [], lastLapStartElapsedMs: state.elapsedTime.inMilliseconds));
  }

  void _recordAutoLap() {
    // similar to manual lap but mark as automatic
    if (state.status != TrainingStatus.running) return;
    final lapDurationMs = state.elapsedTime.inMilliseconds - state.lastLapStartElapsedMs;
    final newLapTimes = List<int>.from(state.lapTimesMillis)..add(lapDurationMs);
    final newLastLapStart = state.elapsedTime.inMilliseconds;
    emit(state.copyWith(lapTimesMillis: newLapTimes, lastLapStartElapsedMs: newLastLapStart));
  }

  void pauseTraining() {
    if (state.status != TrainingStatus.running) return;
    _timer?.cancel();
    emit(state.copyWith(status: TrainingStatus.paused));
  }

  void resumeTraining() {
    if (state.status != TrainingStatus.paused) return;
    emit(state.copyWith(status: TrainingStatus.running));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsedTime: state.elapsedTime + const Duration(seconds: 1)));
    });
  }

  Future<void> stopTraining() async {
    if (state.status == TrainingStatus.notStarted) return;

    _timer?.cancel();
    await _bleStateSub?.cancel();
    _bleStateSub = null;

    // Build SwimSession from history and elapsed time
    final session = SwimSession()
      ..startTime = _startTime ?? DateTime.now().subtract(state.elapsedTime)
      ..endTime = DateTime.now()
      ..elapsedTime = state.elapsedTime.inSeconds
      ..distance = state.lapTimesMillis.isNotEmpty ? (state.lapTimesMillis.length * state.poolLengthMeters).toDouble() : (state.dataHistory.isNotEmpty ? state.dataHistory.last.distance : 0.0)
      ..totalStrokes = state.dataHistory.isNotEmpty ? state.dataHistory.last.strokes : 0
      ..averageHeartRate = state.dataHistory.isNotEmpty
          ? (state.dataHistory.map((d) => d.heartRate).reduce((a, b) => a + b) ~/ state.dataHistory.length)
          : 0
      ..maxHeartRate = state.dataHistory.isNotEmpty
          ? state.dataHistory.map((d) => d.heartRate).reduce((a, b) => a > b ? a : b)
          : 0
      ..averagePace = state.dataHistory.isNotEmpty
          ? (state.dataHistory.map((d) => d.pace).reduce((a, b) => a + b) / state.dataHistory.length)
          : 0.0
      ..laps = state.dataHistory.isNotEmpty ? (state.dataHistory.last.distance ~/ 25).toInt() : 0
      ..swimStyle = 'unknown'
      ..calories = 0
      ..heartRateData = state.dataHistory.map((d) => d.heartRate).toList()
      ..paceData = state.dataHistory.map((d) => d.pace).toList()
      ..strokeData = state.dataHistory.map((d) => d.strokes).toList();
    // attach lap times (milliseconds)
    session.lapTimes = state.lapTimesMillis.isNotEmpty ? List<int>.from(state.lapTimesMillis) : null;

    await sessionRepo.add(session);

    emit(state.copyWith(status: TrainingStatus.finished, completedSession: session));
  }

  Future<SwimSession> _autoSavePartialSession() async {
    // Save a partial session with available data so progress isn't lost
    final partial = SwimSession()
      ..startTime = _startTime ?? DateTime.now().subtract(state.elapsedTime)
      ..endTime = DateTime.now()
      ..elapsedTime = state.elapsedTime.inSeconds
      ..distance = state.dataHistory.isNotEmpty ? state.dataHistory.last.distance : 0.0
      ..totalStrokes = state.dataHistory.isNotEmpty ? state.dataHistory.last.strokes : 0
      ..averageHeartRate = state.dataHistory.isNotEmpty
          ? (state.dataHistory.map((d) => d.heartRate).reduce((a, b) => a + b) ~/ state.dataHistory.length)
          : 0
      ..maxHeartRate = state.dataHistory.isNotEmpty
          ? state.dataHistory.map((d) => d.heartRate).reduce((a, b) => a > b ? a : b)
          : 0
      ..averagePace = state.dataHistory.isNotEmpty
          ? (state.dataHistory.map((d) => d.pace).reduce((a, b) => a + b) / state.dataHistory.length)
          : 0.0
      ..laps = state.lapTimesMillis.isNotEmpty ? state.lapTimesMillis.length : (state.dataHistory.isNotEmpty ? (state.dataHistory.last.distance ~/ 25).toInt() : 0)
      ..swimStyle = 'unknown'
      ..calories = 0
      ..heartRateData = state.dataHistory.map((d) => d.heartRate).toList()
      ..paceData = state.dataHistory.map((d) => d.pace).toList()
      ..strokeData = state.dataHistory.map((d) => d.strokes).toList();
    partial.lapTimes = state.lapTimesMillis.isNotEmpty ? List<int>.from(state.lapTimesMillis) : null;

    await sessionRepo.add(partial);
    // notify UI that a partial was saved
    emit(state.copyWith(lastAutoSavedPartial: partial));
    return partial;
  }

  /// Clear the last auto-saved partial marker after UI handled it
  void clearLastAutoSaved() {
    if (state.lastAutoSavedPartial != null) {
      emit(state.copyWith(lastAutoSavedPartial: null));
    }
  }

  bool _isValidTrainingData(TrainingData d) {
    // basic validation to filter out noise/garbage
    if (d.heartRate < 30 || d.heartRate > 250) return false;
    if (d.pace.isNaN || d.pace <= 0.0 || d.pace > 10.0) return false; // minutes/100m
    if (d.distance.isNaN || d.distance < 0.0) return false;
    if (d.strokes < 0 || d.strokes > 1000) return false;
    return true;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _bleStateSub?.cancel();
    return super.close();
  }
}
