import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart' show Icon, Icons, ScaffoldMessenger, SnackBar, Colors, SizedBox, Row, Text, TextStyle;
import 'package:flutter/widgets.dart' show BuildContext, WidgetsBinding;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/ble_repository_improved.dart';
import '../live_training/live_training_cubit.dart';
import '../analytics/analytics_cubit.dart';

enum BleStatus { disconnected, scanning, connecting, connected, reconnecting, error }

class BleConnectionState {
  final BleStatus status;
  final String? deviceId;
  final String? deviceName;
  final TrainingData? lastData;
  final String? errorMessage;
  final int reconnectAttempts;

  BleConnectionState({
    required this.status,
    this.deviceId,
    this.deviceName,
    this.lastData,
    this.errorMessage,
    this.reconnectAttempts = 0,
  });

  BleConnectionState copyWith({
    BleStatus? status,
    String? deviceId,
    String? deviceName,
    TrainingData? lastData,
    String? errorMessage,
    int? reconnectAttempts,
  }) {
    return BleConnectionState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lastData: lastData ?? this.lastData,
      errorMessage: errorMessage ?? this.errorMessage,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

class BleConnectionCubit extends Cubit<BleConnectionState> {
  final BleRepository _bleRepository;
  final Stream<TrainingData> Function(String) connectStream;
  StreamSubscription<TrainingData>? _sub;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 2;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  
  // ✅ FIX #1: Store last connected device for reconnect
  String? _lastConnectedDeviceId;
  String? _lastConnectedDeviceName;
  
  // ✅ Analytics reference for tracking
  AnalyticsCubit? _analyticsCubit;
  
  // ✅ PROVIDER SCOPE FIX: Direct reference to LiveTrainingCubit (set after both cubits created)
  LiveTrainingCubit? _liveTrainingCubit;

  BleConnectionCubit({
    required this.connectStream,
    required BleRepository bleRepository,
    AnalyticsCubit? analyticsCubit,
  })  : _bleRepository = bleRepository,
        _analyticsCubit = analyticsCubit,
        _liveTrainingCubit = null,  // ✅ Always null initially, will be set via setLiveTrainingCubit()
        super(BleConnectionState(status: BleStatus.disconnected)) {
    // 🎯 LOG #2: Constructor diagnostics
    debugPrint('🔧 BleConnectionCubit constructor called');
    debugPrint('🔧 BleConnectionCubit: _liveTrainingCubit is initially NULL (will be set via setter)');
    debugPrint('🔴 BleConnectionCubit: HR callbacks NOT YET ATTACHED - waiting for setLiveTrainingCubit()');
    
    // ✅ Setup disconnect callback (this doesn't depend on LiveTrainingCubit)
    _bleRepository.onDeviceDisconnected = (deviceId) {
      _handleDeviceDisconnected(deviceId);
      debugPrint('🔄 Disconnect callback triggered - will auto-save if needed');
      
      // ✅ FIX #9: Auto-save partial session on disconnect
      try {
        // Get LiveTrainingCubit from current context and trigger auto-save
        final context = _findBuildContext();
        if (context != null && context.mounted) {
          context.read<LiveTrainingCubit>().autoSavePartialSessionOnDisconnect(deviceId);
          
          // ✅ Track auto-save
          _analyticsCubit?.trackAutoSaveTriggered(deviceId, 'Device disconnected');
          
          // ✅ Show snackbar feedback to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Session auto-saved', style: TextStyle(color: Colors.white)),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green.shade700,
            ),
          );
          
          debugPrint('✅ Auto-save triggered for device: $deviceId');
        }
      } catch (e) {
        debugPrint('⚠️ Could not trigger auto-save: $e');
      }
    };
    
    // NOTE: HR callback is NOT attached here to avoid null reference!
    // It will be attached in setLiveTrainingCubit() method after both cubits are initialized
  }

  /// ✅ CRITICAL FIX: Setter to safely attach LiveTrainingCubit after both cubits are initialized
  /// This ensures _liveTrainingCubit is NOT null when HR callbacks are triggered
  void setLiveTrainingCubit(LiveTrainingCubit cubit) {
    // 🎯 LOG: Setter diagnostics
    debugPrint('🔧 setLiveTrainingCubit() called with: $cubit');
    
    _liveTrainingCubit = cubit;
    
    if (_liveTrainingCubit == null) {
      debugPrint('🔴 setLiveTrainingCubit() WARNING: cubit is NULL!');
      return;
    }
    
    debugPrint('✅ setLiveTrainingCubit() SUCCESS: stored reference to LiveTrainingCubit');
    
    // ✅ RE-ATTACH callback with proper reference
    debugPrint('🔧 RE-attaching HR callback with valid reference...');
    _bleRepository.onHeartRateDataReceived = (hrValue, deviceId) {
      // 🎯 LOG: HR callback diagnostics (only in debug mode to save battery)
      if (kDebugMode) {
        debugPrint('🔧 HR Callback (re-attached): $hrValue bpm from $deviceId');
        debugPrint('🔧 HR Callback: checking _liveTrainingCubit...');
      }
      
      if (_liveTrainingCubit == null) {
        if (kDebugMode) {
          debugPrint('🔴 HR Callback: _liveTrainingCubit is NULL - CANNOT update!');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('✅ HR Callback: _liveTrainingCubit is OK, calling updateHeartRate()');
      }
      
      try {
        _liveTrainingCubit!.updateHeartRate(hrValue, deviceId: deviceId);
        if (kDebugMode) {
          debugPrint('✅ HR Callback: updateHeartRate() called successfully');
        }
      } catch (e) {
        debugPrint('⚠️ HR Callback: Could not update heart rate: $e');
      }
    };
    debugPrint('✅ RE-attached HR callback complete');
  }

  /// ✅ CRITICAL: Cleanup method to prevent resource leak
  /// Call this when training ends to detach HR callback and save battery
  void clearLiveTrainingCubit() {
    debugPrint('🔧 clearLiveTrainingCubit() called - detaching HR callback to save battery');
    
    if (_liveTrainingCubit == null) {
      if (kDebugMode) {
        debugPrint('⚠️ clearLiveTrainingCubit() - _liveTrainingCubit is already null');
      }
      return;
    }
    
    _liveTrainingCubit = null;
    debugPrint('✅ clearLiveTrainingCubit() complete - HR callback DETACHED');
    
    // Re-attach a dummy callback that logs and ignores to prevent NPE
    _bleRepository.onHeartRateDataReceived = (hrValue, deviceId) {
      // Silently ignore - callback is detached (no logs in release mode to save battery)
      if (kDebugMode) {
        debugPrint('⏭️ HR data received while training inactive: $hrValue bpm (ignored)');
      }
    };
  }

  /// Helper: Find BuildContext from widget tree
  BuildContext? _findBuildContext() {
    try {
      // Get context from the root element if available
      final element = WidgetsBinding.instance.rootElement;
      if (element != null) {
        return element;
      }
    } catch (e) {
      debugPrint('⚠️ Could not find root element: $e');
    }
    return null;
  }

  /// Called by BleRepository when device disconnects
  Future<void> _handleDeviceDisconnected(String deviceId) async {
    debugPrint('🔌 BLE disconnect callback received for $deviceId');
    
    // ✅ Track device disconnect
    _analyticsCubit?.trackDeviceDisconnect(deviceId);
    
    if (!_shouldReconnect) {
      debugPrint('❌ Reconnection disabled, staying disconnected');
      emit(state.copyWith(status: BleStatus.disconnected));
      return;
    }

    // Attempt to reconnect
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      emit(state.copyWith(
        status: BleStatus.reconnecting,
        errorMessage: 'Reconnecting... (${_reconnectAttempts}/$_maxReconnectAttempts)',
        reconnectAttempts: _reconnectAttempts,
      ));

      // ✅ Track reconnect attempt
      _analyticsCubit?.trackReconnectAttempt(deviceId, _reconnectAttempts);

      debugPrint('🔄 Reconnection attempt $_reconnectAttempts of $_maxReconnectAttempts');
      await Future.delayed(_reconnectDelay);

      // Retry connection
      if (state.deviceId != null) {
        await connect(state.deviceId!, state.deviceName ?? 'Unknown Device');
      }
    } else {
      debugPrint('❌ Max reconnection attempts (${_maxReconnectAttempts}) reached');
      emit(state.copyWith(
        status: BleStatus.error,
        errorMessage: 'Device disconnected. Max reconnection attempts reached.',
        reconnectAttempts: _reconnectAttempts,
      ));
      _shouldReconnect = false;
    }
  }

  Future<void> scan() async {
    emit(state.copyWith(status: BleStatus.scanning));
    try {
      // scanning is a UI-level action; cubit returns to previous disconnected unless connected
      await Future.delayed(const Duration(seconds: 1));
      if (state.status != BleStatus.connected) {
        emit(state.copyWith(status: BleStatus.disconnected));
      }
    } catch (e) {
      emit(state.copyWith(status: BleStatus.disconnected, errorMessage: e.toString()));
    }
  }

  /// Connect to device with disconnect handling + reconnect logic
  Future<void> connect(String id, String name) async {
    // ✅ FIX #1: Save device for later reconnect
    _lastConnectedDeviceId = id;
    _lastConnectedDeviceName = name;
    
    // ✅ FIX #4: Check if already connected to prevent duplicate connections
    if (state.status == BleStatus.connected && state.deviceId == id) {
      debugPrint('⚠️ Already connected to device $id, skipping connect');
      return;
    }
    
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    
    emit(state.copyWith(status: BleStatus.connecting, deviceId: id, deviceName: name));
    try {
      debugPrint('📱 Attempting connection to: $name ($id)');
      
      // simulate connect delay
      await Future.delayed(const Duration(milliseconds: 500));
      emit(state.copyWith(status: BleStatus.connected));

      // ✅ FIX #5: Cancel previous subscription before creating new one
      await _sub?.cancel();
      _sub = connectStream(id).listen(
        (data) {
          emit(state.copyWith(lastData: data, status: BleStatus.connected, errorMessage: null));
        },
        onError: (error) {
          debugPrint('❌ Stream error: $error');
          emit(state.copyWith(
            status: BleStatus.error,
            errorMessage: 'Connection lost: $error',
          ));
          _handleDeviceDisconnected(id);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      emit(state.copyWith(
        status: BleStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Manual disconnect (prevents auto-reconnect)
  Future<void> disconnect() async {
    _shouldReconnect = false;
    // ✅ FIX #5: Proper cleanup of subscription
    await _sub?.cancel();
    _sub = null;
    _reconnectAttempts = 0;
    _lastConnectedDeviceId = null;
    _lastConnectedDeviceName = null;
    emit(BleConnectionState(status: BleStatus.disconnected));
    debugPrint('🔌 Manual disconnect - cleaned up resources');
  }

  @override
  Future<void> close() {
    _shouldReconnect = false;
    _sub?.cancel();
    return super.close();
  }
}
