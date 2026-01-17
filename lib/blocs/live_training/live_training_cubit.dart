import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble_connection/ble_connection_cubit.dart';
import '../../repositories/swim_session_repository.dart';
import '../../models/swim_session.dart';
import '../../repositories/ble_repository_improved.dart';
import 'live_training_state.dart';

class LiveTrainingCubit extends Cubit<LiveTrainingState> {
  BleConnectionCubit? bleCubit;  // ✅ Mutable, not final
  final SwimSessionRepository sessionRepo;

  Timer? _timer;
  StreamSubscription? _bleStateSub;
  DateTime? _startTime;
  // start time in milliseconds since epoch for high-resolution timer
  int _startTimeMillis = 0;

  LiveTrainingCubit({this.bleCubit, required this.sessionRepo}) : super(LiveTrainingState());

  /// ✅ Set BleConnectionCubit reference after initialization
  void setBleCubit(BleConnectionCubit cubit) {
    bleCubit = cubit;
    debugPrint('✅ BleCubit reference set in LiveTrainingCubit');
  }

  void startTraining() {
    if (state.status == TrainingStatus.running) return;

    _startTime = DateTime.now();
    _startTimeMillis = _startTime!.millisecondsSinceEpoch;
    emit(LiveTrainingState(status: TrainingStatus.running, elapsedTime: Duration.zero, elapsedTimeMillis: 0, currentTimeMillis: _startTimeMillis, dataHistory: [], lapTimesMillis: [], lastLapStartElapsedMs: 0));

    // High-resolution timer with centiseconds (10ms interval)
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - _startTimeMillis;
      emit(state.copyWith(
        elapsedTimeMillis: elapsed,
        currentTimeMillis: now,
        elapsedTime: Duration(milliseconds: elapsed),
      ));
    });

    // Subscribe to BLE cubit stream for live TrainingData and connection status
    if (bleCubit != null) {
      _bleStateSub = bleCubit!.stream.listen((bleState) async {
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
    // Re-sync startTimeMillis so elapsed continues from previous value
    final now = DateTime.now().millisecondsSinceEpoch;
    final prevElapsed = state.elapsedTimeMillis > 0 ? state.elapsedTimeMillis : state.elapsedTime.inMilliseconds;
    _startTimeMillis = now - prevElapsed;
    emit(state.copyWith(status: TrainingStatus.running));
    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final now2 = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now2 - _startTimeMillis;
      emit(state.copyWith(
        elapsedTimeMillis: elapsed,
        currentTimeMillis: now2,
        elapsedTime: Duration(milliseconds: elapsed),
      ));
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
      ..elapsedTime = (state.elapsedTimeMillis > 0 ? (state.elapsedTimeMillis ~/ 1000) : state.elapsedTime.inSeconds)
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

  /// ✅ NEW: Update heart rate from BleRepository real-time callback
  void updateHeartRate(int hrValue, {String? deviceId}) {
    // 🎯 LOG #1: Entry diagnostics (only in debug mode to save battery)
    if (kDebugMode) {
      debugPrint('📥 updateHeartRate() CALLED: $hrValue bpm, device: $deviceId');
      debugPrint('📥 Current training status: ${state.status}');
      debugPrint('📥 Current state.currentData exists: ${state.currentData != null}');
      debugPrint('📥 Current state.currentData.heartRate: ${state.currentData?.heartRate ?? 'null'}');
    }
    
    // Only update HR if training is running or paused (not finished)
    if (state.status != TrainingStatus.running && state.status != TrainingStatus.paused) {
      if (kDebugMode) {
        debugPrint('⏭️ updateHeartRate() SKIPPED - status is ${state.status}, not running/paused');
      }
      return;
    }
    
    // If we don't have currentData yet, create it with HR only
    if (state.currentData == null) {
      final newData = TrainingData(
        hrValue,
        0.0,  // distance
        0,    // strokes
        0.0,  // pace
      );
      emit(state.copyWith(currentData: newData));
      if (kDebugMode) {
        debugPrint('✅ Initial HR set in currentData: $hrValue bpm');
        debugPrint('📤 EMITTED new state with initial HR: $hrValue bpm');
        debugPrint('📤 New state.currentData.heartRate: ${state.currentData?.heartRate ?? 'ERROR: still null!'}');
      }
    } else {
      // Update existing data with new HR
      final updatedData = TrainingData(
        hrValue,
        state.currentData!.distance,
        state.currentData!.strokes,
        state.currentData!.pace,
        speed: state.currentData!.speed,
      );
      emit(state.copyWith(currentData: updatedData));
      if (kDebugMode) {
        debugPrint('✅ HR updated in existing data: $hrValue bpm');
        debugPrint('📤 EMITTED new state with updated HR: $hrValue bpm');
        debugPrint('📤 New state.currentData.heartRate: ${state.currentData?.heartRate ?? 'ERROR: still null!'}');
      }
    }
  }

  /// ✅ PUBLIC: Called by BleConnectionCubit when device disconnects
  /// Saves partial session to prevent data loss
  Future<SwimSession> autoSavePartialSessionOnDisconnect(String deviceId) async {
    if (state.status != TrainingStatus.running && state.status != TrainingStatus.paused) {
      debugPrint('⚠️ Not in training session, skipping auto-save');
      return SwimSession();
    }
    
    debugPrint('💾 Auto-saving partial session (device: $deviceId disconnected)');
    return await _autoSavePartialSession();
  }

  @override
  Future<void> close() {
    debugPrint('🔧 LiveTrainingCubit.close() called - cleaning up resources...');
    
    _timer?.cancel();
    _bleStateSub?.cancel();
    
    // ✅ CRITICAL FIX: Detach HR callback to prevent resource leak (battery drain)
    if (bleCubit != null) {
      debugPrint('🔧 Calling bleCubit.clearLiveTrainingCubit() to detach HR callback...');
      bleCubit!.clearLiveTrainingCubit();
      debugPrint('✅ HR callback detached - no more unnecessary updates');
    } else {
      debugPrint('⚠️ _bleCubit is null - HR callback may still be attached');
    }
    
    debugPrint('✅ LiveTrainingCubit.close() complete');
    return super.close();
  }
}
