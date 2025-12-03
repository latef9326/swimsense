import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_service_uuids.dart';

class BleDevice {
  final String id;
  final String name;
  BleDevice(this.id, this.name);
}

/// Rich training data produced by device (real or simulated)
class TrainingData {
  final int heartRate;
  final double distance; // meters
  final int strokes;
  final double pace; // minutes per 100m

  TrainingData(this.heartRate, this.distance, this.strokes, this.pace);
}

/// Real BLE repository using flutter_reactive_ble with simulation fallback.
class BleRepository {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final _rand = Random();
  bool useSimulation = false; // Toggle between real and simulated BLE
  StreamSubscription? _scanSub;
  StreamSubscription? _connectionSub;
  final Map<String, int> _connectionState = {}; // Track connection states

  /// Request Bluetooth permissions.
  Future<bool> requestBluetoothPermissions() async {
    try {
      // Request location and Bluetooth permissions (Android requires location)
      final locationStatus = await Permission.location.request();
      final bluetoothStatus = await Permission.bluetooth.request();

      if (locationStatus.isDenied || bluetoothStatus.isDenied) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if Bluetooth is available and enabled.
  Future<bool> isBluetoothAvailable() async {
    try {
      final state = await _ble.statusStream.first;
      return state == BleStatus.ready;
    } catch (e) {
      debugPrint('Error checking BLE status: $e');
      return false;
    }
  }

  /// Scan for BLE devices with Heart Rate or cycling power services.
  Future<List<BleDevice>> scan({
    Duration timeout = const Duration(seconds: 5),
    bool forceSimulation = false,
  }) async {
    // Use simulation if explicitly requested or if BLE unavailable
    if (forceSimulation || useSimulation) {
      return _simulateScan(timeout);
    }

    try {
      // Check permissions first
      final hasPermissions = await requestBluetoothPermissions();
      if (!hasPermissions) {
        debugPrint('Bluetooth permissions denied, using simulation');
        return _simulateScan(timeout);
      }

      // Check if BLE is available
      final isBleAvailable = await isBluetoothAvailable();
      if (!isBleAvailable) {
        debugPrint('BLE not available, using simulation');
        return _simulateScan(timeout);
      }

      // Scan for real devices
      final devices = <BleDevice>[];
      final discoveredIds = <String>{};

      final scanStream = _ble.scanForDevices(
        withServices: [
          // Heart Rate Service
          Uuid.parse(BleServiceUuids.heartRateService),
        ],
        scanMode: ScanMode.balanced,
        requireLocationServicesEnabled: false,
      );

      _scanSub?.cancel();
      _scanSub = scanStream.listen(
        (device) {
          if (discoveredIds.add(device.id)) {
            devices.add(BleDevice(device.id, device.name));
          }
        },
        onError: (e) => debugPrint('Scan error: $e'),
      );

      // Wait for timeout
      await Future.delayed(timeout);
      await _scanSub?.cancel();
      _scanSub = null;

      // If no real devices found, return simulation
      if (devices.isEmpty) {
        debugPrint('No BLE devices found, using simulation');
        return _simulateScan(timeout);
      }

      return devices;
    } catch (e) {
      debugPrint('BLE scan error: $e, falling back to simulation');
      return _simulateScan(timeout);
    }
  }

  /// Connect to device and stream training data.
  Stream<TrainingData> connectToDevice(String id, {bool forceSimulation = false}) async* {
    if (forceSimulation || useSimulation) {
      yield* _simulateConnection(id);
      return;
    }

    try {
      final connection = _ble.connectToDevice(
        id: id,
        connectionTimeout: const Duration(seconds: 10),
      );

      _connectionSub?.cancel();
      _connectionSub = connection.listen(
        (connectionState) {
          _connectionState[id] = connectionState.connectionState.index;
          debugPrint('Connection state: ${connectionState.connectionState}');
        },
        onError: (e) => debugPrint('Connection error: $e'),
      );

      // Wait a moment for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // Subscribe to Heart Rate Measurement characteristic
      final hrCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleServiceUuids.heartRateService),
        characteristicId: Uuid.parse(BleServiceUuids.heartRateMeasurement),
        deviceId: id,
      );

      // Start notifications
      await _ble.subscribeToCharacteristic(hrCharacteristic).first;

      double distance = 0.0;
      int strokes = 0;
      int hr = 100;

      // Stream HR data
      yield* _ble.subscribeToCharacteristic(hrCharacteristic).map((data) {
        if (data.isNotEmpty) {
          // HR measurement is typically in the second byte
          hr = data.length > 1 ? data[1] : data[0];
        }

        // Simulate other metrics based on HR
        distance += 0.5; // small increment per update
        strokes += 1;
        final pace = 2.0 + (hr - 100) * 0.01; // Rough estimation

        return TrainingData(hr, distance, strokes, pace);
      }).handleError((e) {
        debugPrint('HR subscription error: $e, falling back to simulation');
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) {
            // Fall back to simulation on any error
            _simulateConnection(id).listen(
              sink.add,
              onError: sink.addError,
              onDone: sink.close,
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('BLE connection error: $e, using simulation');
      yield* _simulateConnection(id);
    }
  }

  /// Simulated BLE device scan (fallback).
  Future<List<BleDevice>> _simulateScan(Duration timeout) async {
    await Future.delayed(timeout);
    return [
      BleDevice('sim-hr-1', 'Simulated HR Monitor 1'),
      BleDevice('sim-hr-2', 'Simulated HR Monitor 2'),
    ];
  }

  /// Simulated device connection (fallback).
  Stream<TrainingData> _simulateConnection(String id) async* {
    double distance = 0.0;
    int strokes = 0;
    int hr = 100 + _rand.nextInt(30);
    while (true) {
      await Future.delayed(const Duration(seconds: 2));

      hr = (hr + (_rand.nextInt(7) - 3)).clamp(40, 200);
      distance += 25.0;
      strokes += 8 + _rand.nextInt(6);
      final pace = 1.5 + _rand.nextDouble() * 1.5;

      yield TrainingData(hr, distance, strokes, pace);
    }
  }

  /// Toggle between real and simulated BLE.
  void setSimulationMode(bool enabled) {
    useSimulation = enabled;
  }

  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
  }
}
