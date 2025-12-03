import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/ble_repository.dart';

enum BleStatus { disconnected, scanning, connecting, connected }

class BleConnectionState {
  final BleStatus status;
  final String? deviceId;
  final String? deviceName;
  final TrainingData? lastData;

  BleConnectionState({required this.status, this.deviceId, this.deviceName, this.lastData});

  BleConnectionState copyWith({BleStatus? status, String? deviceId, String? deviceName, TrainingData? lastData}) {
    return BleConnectionState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      lastData: lastData ?? this.lastData,
    );
  }
}

class BleConnectionCubit extends Cubit<BleConnectionState> {
  final Stream<TrainingData> Function(String) connectStream;
  StreamSubscription<TrainingData>? _sub;

  BleConnectionCubit({required this.connectStream}) : super(BleConnectionState(status: BleStatus.disconnected));

  Future<void> scan() async {
    emit(state.copyWith(status: BleStatus.scanning));
    try {
      // scanning is a UI-level action; cubit returns to previous disconnected unless connected
      await Future.delayed(const Duration(seconds: 1));
      if (state.status != BleStatus.connected) {
        emit(state.copyWith(status: BleStatus.disconnected));
      }
    } catch (e) {
      emit(state.copyWith(status: BleStatus.disconnected));
    }
  }

  Future<void> connect(String id, String name) async {
    emit(state.copyWith(status: BleStatus.connecting, deviceId: id, deviceName: name));
    try {
      // simulate connect delay
      await Future.delayed(const Duration(milliseconds: 500));
      emit(state.copyWith(status: BleStatus.connected));

      _sub = connectStream(id).listen(
        (data) {
          emit(state.copyWith(lastData: data, status: BleStatus.connected));
        },
        onError: (error) {
          emit(state.copyWith(status: BleStatus.disconnected));
        },
        cancelOnError: true,
      );
    } catch (e) {
      emit(state.copyWith(status: BleStatus.disconnected));
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    emit(BleConnectionState(status: BleStatus.disconnected));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
