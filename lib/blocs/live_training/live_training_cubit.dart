import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../ble_connection/ble_connection_cubit.dart';
import '../user_profile/user_profile_cubit.dart';
import '../../repositories/swim_session_repository.dart';
import '../../models/swim_session.dart';
import '../../models/user_profile.dart';
import '../../repositories/ble_repository_improved.dart';
import '../../services/location_service.dart';
import 'live_training_state.dart';

class LiveTrainingCubit extends Cubit<LiveTrainingState> {
  BleConnectionCubit? bleCubit;  // ✅ Mutable, not final
  UserProfileCubit? userProfileCubit;  // ✅ For user metrics
  final SwimSessionRepository sessionRepo;
  final LocationService _locationService = LocationService();

  Timer? _timer;
  StreamSubscription? _bleStateSub;
  StreamSubscription? _locationSub;
  DateTime? _startTime;
  // start time in milliseconds since epoch for high-resolution timer
  int _startTimeMillis = 0;
  
  // GPS distance tracking
  Position? _lastPosition;
  double _totalDistance = 0.0;

  LiveTrainingCubit({this.bleCubit, required this.sessionRepo}) : super(LiveTrainingState());

  /// ✅ Set BleConnectionCubit reference after initialization
  void setBleCubit(BleConnectionCubit cubit) {
    bleCubit = cubit;
    debugPrint('✅ BleCubit reference set in LiveTrainingCubit');
  }

  /// ✅ Set UserProfileCubit reference after initialization
  void setUserProfileCubit(UserProfileCubit cubit) {
    userProfileCubit = cubit;
    debugPrint('✅ UserProfileCubit reference set in LiveTrainingCubit');
  }

  void startTraining() async {
    if (state.status == TrainingStatus.running) return;

    // ✅ CRITICAL: Cancel any old GPS stream before starting fresh
    await _locationSub?.cancel();
    _locationSub = null;
    _totalDistance = 0.0;
    _lastPosition = null;
    debugPrint('📍 INITIAL RESET: distance=0.0m, position=null');
    
    _startTime = DateTime.now();
    _startTimeMillis = _startTime!.millisecondsSinceEpoch;
    
    emit(LiveTrainingState(status: TrainingStatus.running, elapsedTime: Duration.zero, elapsedTimeMillis: 0, currentTimeMillis: _startTimeMillis, dataHistory: [], lapTimesMillis: [], lastLapStartElapsedMs: 0));

    debugPrint('📍 startTraining() - Checking location permission...');
    
    // 🔧 PROPER RUNTIME PERMISSION CHECK using Geolocator - ASYNC, DON'T BLOCK
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️  Location permission denied - requesting...');
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('🔴 Location permission denied forever - opening app settings');
        await Geolocator.openLocationSettings();
      } else if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        debugPrint('✅ Location permission granted - starting GPS stream');
        // ✅ CRITICAL FIX: Always subscribe (state was already emitted as running above)
        _subscribeToLocationUpdates();
      } else {
        debugPrint('⚠️  Location permission: $permission - cannot start GPS');
      }
    } catch (e) {
      debugPrint('🔴 Permission error: $e');
    }

    // ✅ CRITICAL: Start timer IMMEDIATELY (don't wait for GPS permission async)
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

          // 🔧 CRITICAL MERGE FIX: Preserve GPS distance and speed when BLE emits!
          // BLE provides HR and strokes, but GPS provides distance and speed
          final mergedBleData = TrainingData(
            last.heartRate,                           // From BLE
            state.currentData?.distance ?? 0.0,       // ✅ PRESERVE GPS distance
            last.strokes,                             // From BLE
            state.currentData?.pace ?? last.pace,     // Preserve GPS pace
            speed: state.currentData?.speed ?? last.speed,  // ✅ PRESERVE GPS speed
          );
          emit(state.copyWith(currentData: mergedBleData, dataHistory: newHistory));
        }
      }
      });
    }
  }

  /// ✅ NEW: Subscribe to GPS location updates and calculate distance
  /// CRITICAL: Merge GPS data with BLE data (strokes, HR) instead of overwriting
  void _subscribeToLocationUpdates() {
    debugPrint('📍 _subscribeToLocationUpdates() - Getting position stream...');
    try {
      _locationSub = _locationService.getPositionStream().listen(
        (position) {
          // 📍 RAW GPS LOG - always capture
          debugPrint('📍 GPS RAW: acc=${position.accuracy.toStringAsFixed(1)}m, speed=${position.speed.toStringAsFixed(2)}m/s, lat=${position.latitude.toStringAsFixed(6)}, lon=${position.longitude.toStringAsFixed(6)}');
          
          if (state.status != TrainingStatus.running) {
            debugPrint('⏭️ GPS ignored - status is ${state.status}, not running');
            return;
          }
          
          // ✅ Filter out poor GPS accuracy (> 40 meters for indoor tolerance)
          // Indoor GPS is typically 15-30m, outdoor is 5-10m
          if (position.accuracy > 40.0) {
            debugPrint('📍 GPS accuracy POOR: ${position.accuracy.toStringAsFixed(1)}m > 40m threshold - ignoring');
            return;
          }
          
          if (kDebugMode) {
            debugPrint('📍 Processing GPS Position: lat=${position.latitude}, lon=${position.longitude}, speed=${position.speed.toStringAsFixed(2)} m/s');
          }
          
          // Initialize first position
          if (_lastPosition == null) {
            _lastPosition = position;
            if (kDebugMode) {
              debugPrint('📍 First valid position recorded for distance baseline');
            }
            return;
          }
          
          // Calculate distance between last and current position
          final distance = LocationService.calculateDistance(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          
          // 🔧 CRITICAL FILTERS: Ignore GPS drift and impossible values
          if (distance < 0.5) {
            // GPS drift - update position but don't count
            _lastPosition = position;
            if (kDebugMode) {
              debugPrint('📍 GPS drift ignored (${distance.toStringAsFixed(2)}m < 0.5m threshold)');
            }
            return;
          }
          
          if (distance > 50.0) {
            // GPS jump - ignore completely (likely error)
            if (kDebugMode) {
              debugPrint('📍 GPS jump ignored (${distance.toStringAsFixed(1)}m > 50m threshold)');
            }
            return;
          }
          
          // ✅ REMOVED: speed < 0.3 filter - was blocking swimming with small speeds!
          
          _totalDistance += distance;
          _lastPosition = position;
          
          if (kDebugMode) {
            debugPrint('📍✅ Distance INCREMENT: ${distance.toStringAsFixed(2)}m, TOTAL: ${_totalDistance.toStringAsFixed(2)}m, Speed: ${position.speed.toStringAsFixed(2)} m/s');
          }
          
          // Calculate pace: min per 100m
          final pace = _totalDistance > 0 
            ? (state.elapsedTime.inSeconds / 60) / (_totalDistance / 100)
            : 0.0;
          
          // 🔧 CRITICAL FIX: MERGE GPS data with existing BLE data (HR, strokes)
          // Don't overwrite BLE-sourced fields with zero values!
          final mergedData = TrainingData(
            state.currentData?.heartRate ?? 0,  // From BLE (preserve HR)
            _totalDistance,                      // From GPS (updated distance)
            state.currentData?.strokes ?? 0,     // From BLE (preserve strokes - don't overwrite with 0!)
            pace,                                // Calculated from GPS + elapsed time
            speed: position.speed,               // From GPS (use position.speed, not derived)
          );
          
          emit(state.copyWith(
            currentData: mergedData,
            elapsedTimeMillis: DateTime.now().millisecondsSinceEpoch - _startTimeMillis,
          ));
        },
        onError: (error, stackTrace) {
          debugPrint('🔴 GPS Stream Error: $error');
          debugPrint('Stack: $stackTrace');
        },
        onDone: () {
          debugPrint('⚠️ GPS Stream ended');
        },
      );
      debugPrint('📍 GPS stream listener attached successfully');
    } catch (e, st) {
      debugPrint('🔴 Error subscribing to GPS: $e');
      debugPrint('Stack: $st');
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
    _locationSub?.pause();  // ✅ Pause GPS updates
    emit(state.copyWith(status: TrainingStatus.paused));
  }

  void resumeTraining() {
    if (state.status != TrainingStatus.paused) return;
    _locationSub?.resume();  // ✅ Resume GPS updates
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
    await _locationSub?.cancel();  // ✅ Cancel GPS stream
    _bleStateSub = null;
    _locationSub = null;
    
    // 🔧 BUILD SESSION FIRST with current _totalDistance (BEFORE reset!)
    final finalDistance = _totalDistance > 0 ? _totalDistance : (state.lapTimesMillis.isNotEmpty ? (state.lapTimesMillis.length * state.poolLengthMeters).toDouble() : 0.0);
    debugPrint('📍 Saving session with distance: ${finalDistance.toStringAsFixed(2)}m');

    // Build SwimSession from history and elapsed time
    final session = SwimSession()
      ..startTime = _startTime ?? DateTime.now().subtract(state.elapsedTime)
      ..endTime = DateTime.now()
      ..elapsedTime = (state.elapsedTimeMillis > 0 ? (state.elapsedTimeMillis ~/ 1000) : state.elapsedTime.inSeconds)
      ..distance = finalDistance
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
      ..calories = _calculateCalories()
      ..heartRateData = state.dataHistory.map((d) => d.heartRate).toList()
      ..paceData = state.dataHistory.map((d) => d.pace).toList()
      ..strokeData = state.dataHistory.map((d) => d.strokes).toList();
    // attach lap times (milliseconds)
    session.lapTimes = state.lapTimesMillis.isNotEmpty ? List<int>.from(state.lapTimesMillis) : null;

    await sessionRepo.add(session);

    // 🔧 NOW reset GPS state for next session (AFTER saving!)
    _lastPosition = null;
    _totalDistance = 0.0;
    debugPrint('📍 TOTAL RESET: distance=0.0m, position=null');

    emit(state.copyWith(status: TrainingStatus.finished, completedSession: session));
  }

  Future<SwimSession> _autoSavePartialSession() async {
    // Save a partial session with available data so progress isn't lost
    final partial = SwimSession()
      ..startTime = _startTime ?? DateTime.now().subtract(state.elapsedTime)
      ..endTime = DateTime.now()
      ..elapsedTime = state.elapsedTime.inSeconds
      ..distance = _totalDistance > 0 ? _totalDistance : (state.dataHistory.isNotEmpty ? state.dataHistory.last.distance : 0.0)
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

  /// ✅ NEW: Calculate calories burned using Heart Rate Reserve (Keytel Formula)
  /// Formula adjusts by gender:
  /// - Men: caloriesPerMinute = (-55.0969 + (0.6309 * avgHR) + (0.1988 * weightKg) + (0.2017 * age)) / 4.184
  /// - Women: caloriesPerMinute = (-20.4022 + (0.6309 * avgHR) + (0.1988 * weightKg) + (0.2017 * age)) / 4.184
  int _calculateCalories() {
    if (state.dataHistory.isEmpty) {
      return 0;
    }
    
    // 🔧 Get user profile data (with fallback to defaults)
    final profile = userProfileCubit?.state.profile ?? UserProfileCubit.getDefaultProfile();
    final age = profile.age;
    final weightKg = profile.weightKg;
    
    // Calculate average heart rate from all data points
    final avgHR = state.dataHistory
        .map((d) => d.heartRate)
        .reduce((a, b) => a + b) ~/ state.dataHistory.length;
    
    // Training duration in minutes
    final trainingMinutes = state.elapsedTime.inSeconds / 60;
    
    if (kDebugMode) {
      debugPrint('🔥 Calorie Calculation:');
      debugPrint('  Age: $age years');
      debugPrint('  Weight: ${weightKg.toStringAsFixed(1)} kg');
      debugPrint('  Gender: ${profile.gender}');
      debugPrint('  Avg HR: $avgHR bpm');
      debugPrint('  Duration: ${trainingMinutes.toStringAsFixed(1)} minutes');
    }
    
    // Keytel Formula (kcal/min) - adjusts by gender
    final caloriesPerMinute = (profile.calorieCoefficient + 
        (UserProfile.hrCoefficient * avgHR) + 
        (UserProfile.weightCoefficient * weightKg) + 
        (UserProfile.ageCoefficient * age)) / 4.184;
    
    final totalCalories = (caloriesPerMinute * trainingMinutes).round();
    
    if (kDebugMode) {
      debugPrint('  Calories/min: ${caloriesPerMinute.toStringAsFixed(2)}');
      debugPrint('  Total Calories: $totalCalories kcal');
    }
    
    return totalCalories.clamp(0, 5000); // Max 5000 kcal to prevent outliers
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
