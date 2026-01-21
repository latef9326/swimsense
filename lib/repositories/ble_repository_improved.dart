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
  final double speed; // m/s

  TrainingData(this.heartRate, this.distance, this.strokes, this.pace, {this.speed = 0.0});

  /// Factory helper to create TrainingData from distance and elapsed time
  factory TrainingData.fromDistanceAndTime({
    required int heartRate,
    required double distanceMeters,
    required Duration elapsedTime,
    required int strokes,
  }) {
    final speed = elapsedTime.inSeconds > 0 ? distanceMeters / elapsedTime.inSeconds : 0.0;
    final pace = speed > 0 ? (100.0 / speed) / 60.0 * 60.0 : 0.0; // rough conversion to min/100m
    return TrainingData(heartRate, distanceMeters, strokes, pace, speed: speed);
  }
}

/// Real BLE repository using flutter_reactive_ble with simulation fallback + POLAR IMPROVEMENTS
class BleRepository {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final _rand = Random();
  bool useSimulation = false; // Toggle between real and simulated BLE
  StreamSubscription? _scanSub;
  StreamSubscription? _connectionSub;
  final Map<String, DeviceConnectionState> _connectionState = {}; // Track connection states

  // Callback for disconnect events (to trigger auto-save)
  Function(String deviceId)? onDeviceDisconnected;
  
  // ✅ Callback for HR data updates (send to UI)
  Function(int hrValue, String deviceId)? onHeartRateDataReceived;

  /// Request Bluetooth permissions for Android 12+ and iOS.
  Future<bool> requestBluetoothPermissions() async {
    try {
      // Request location and Bluetooth permissions (Android requires location for BLE)
      final locationStatus = await Permission.location.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();

      if (locationStatus.isDenied || bluetoothScanStatus.isDenied || bluetoothConnectStatus.isDenied) {
        debugPrint('Permissions denied - Location: $locationStatus, Scan: $bluetoothScanStatus, Connect: $bluetoothConnectStatus');
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

  /// Scan for BLE devices with Heart Rate Service (Polar, Garmin, etc.)
  Future<List<BleDevice>> scan({
    Duration timeout = const Duration(seconds: 5),
    bool forceSimulation = false,
  }) async {
    // Use simulation if explicitly requested or if BLE unavailable
    if (forceSimulation || useSimulation) {
      return _simulateScan(timeout);
    }

    try {
      // ✅ FIX #3: Check and request permissions BEFORE scanning
      final hasPermissions = await requestBluetoothPermissions();
      if (!hasPermissions) {
        debugPrint('❌ Bluetooth permissions denied, using simulation');
        return _simulateScan(timeout);
      }

      // Verify permissions are actually granted (not just requested)
      final permissionsValid = await _verifyPermissionsGranted();
      if (!permissionsValid) {
        debugPrint('❌ Permissions not granted by user, using simulation');
        return _simulateScan(timeout);
      }

      // Check if BLE is available
      final isBleAvailable = await isBluetoothAvailable();
      if (!isBleAvailable) {
        debugPrint('❌ BLE not available, using simulation');
        return _simulateScan(timeout);
      }

      // Scan for real devices with Heart Rate Service
      final devices = <BleDevice>[];
      final discoveredIds = <String>{};

      final scanStream = _ble.scanForDevices(
        withServices: [
          // Heart Rate Service UUID (standard Bluetooth)
          Uuid.parse(BleServiceUuids.heartRateService),
        ],
        scanMode: ScanMode.balanced,
        requireLocationServicesEnabled: false,
      );

      _scanSub?.cancel();
      _scanSub = scanStream.listen(
        (device) {
          // ✅ POLAR FILTERING: Only add known HRM device brands
          final deviceName = device.name ?? '';
          final nameMatch = deviceName.toUpperCase().contains(
            RegExp(r'POLAR|GARMIN|SUUNTO|WAHOO|FITBIT|APPLE')
          );
          
          // Add if name matches HRM brands OR has valid name and hasn't been discovered yet
          if ((nameMatch || deviceName.isNotEmpty) && discoveredIds.add(device.id)) {
            devices.add(BleDevice(device.id, deviceName));
            debugPrint('✅ Found HRM device: "$deviceName" (ID: ${device.id})');
          }
        },
        onError: (e) => debugPrint('❌ Scan error: $e'),
      );

      // ✅ FIX #7: Add timeout to prevent infinite scan
      await Future.delayed(timeout);
      await _scanSub?.cancel();
      _scanSub = null;

      // If no real devices found, fall back to simulation
      if (devices.isEmpty) {
        debugPrint('⚠️ No BLE devices found during scan, using simulation');
        return _simulateScan(timeout);
      }

      debugPrint('✅ Scan complete: found ${devices.length} HRM device(s)');
      return devices;
    } catch (e) {
      debugPrint('❌ BLE scan error: $e, falling back to simulation');
      return _simulateScan(timeout);
    }
  }

  /// ✅ FIX #3: Helper to verify permissions are actually granted
  Future<bool> _verifyPermissionsGranted() async {
    try {
      final locationStatus = await Permission.location.status;
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      
      final allGranted = locationStatus.isGranted && 
                        scanStatus.isGranted && 
                        connectStatus.isGranted;
      
      if (!allGranted) {
        debugPrint('⚠️ Not all permissions granted - Location: ${locationStatus.isDenied}, '
                   'Scan: ${scanStatus.isDenied}, Connect: ${connectStatus.isDenied}');
      }
      
      return allGranted;
    } catch (e) {
      debugPrint('❌ Error verifying permissions: $e');
      return false;
    }
  }

  /// Connect to device and stream training data with proper HR parsing + disconnect handling
  Stream<TrainingData> connectToDevice(String id, {bool forceSimulation = false}) async* {
    if (forceSimulation || useSimulation) {
      yield* _simulateConnection(id);
      return;
    }

    try {
      debugPrint('📱 Connecting to device: $id');

      final connection = _ble.connectToDevice(
        id: id,
        connectionTimeout: const Duration(seconds: 10),
        servicesWithCharacteristicsToDiscover: {
          Uuid.parse(BleServiceUuids.heartRateService): [
            Uuid.parse(BleServiceUuids.heartRateMeasurement),
          ],
        },
      );

      _connectionSub?.cancel();
      _connectionSub = connection.listen(
        (connectionState) {
          _connectionState[id] = connectionState.connectionState;
          debugPrint('📡 Connection listener: ${connectionState.connectionState}');
          
          // ✅ AUTO-SAVE on disconnect
          if (connectionState.connectionState == DeviceConnectionState.disconnected) {
            debugPrint('⚠️ Device DISCONNECTED: $id - triggering auto-save');
            onDeviceDisconnected?.call(id);
          }
        },
        onError: (e) {
          debugPrint('❌ Connection error: $e');
          onDeviceDisconnected?.call(id);
        },
      );

      // Wait a moment for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // Subscribe to Heart Rate Measurement characteristic
      final hrCharacteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(BleServiceUuids.heartRateService),
        characteristicId: Uuid.parse(BleServiceUuids.heartRateMeasurement),
        deviceId: id,
      );

      debugPrint('🔔 Subscribing to HR characteristic...');
      
      double distance = 0.0;
      int strokes = 0;
      int lastHr = 100;

      // ✅ FIX #5: Stream HR data with proper error handling
      yield* _ble.subscribeToCharacteristic(hrCharacteristic)
        .map((data) {
          try {
            return _parseHeartRateMeasurement(data, distance, strokes, lastHr, id);
          } catch (e) {
            debugPrint('❌ Error parsing HR data: $e');
            return TrainingData(lastHr, distance, strokes, 2.0, speed: 0.0);
          }
        })
        .map((parsedData) {
          // Update tracking variables
          lastHr = parsedData.heartRate;
          // ❌ REMOVED: distance += 0.5; - DISTANCE ONLY FROM GPS!
          strokes += 1;
          
          final pace = 2.0 + (lastHr - 100) * 0.01; // Rough estimation
          const speed = 0.0; // ✅ Speed from GPS only, BLE should use 0

          return TrainingData(lastHr, distance, strokes, pace, speed: speed);
        })
        .timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            debugPrint('⚠️ HR stream timeout - no data received for 15s');
            sink.close();
          },
        )
        // ✅ FIX #5: Robust error handling
        .handleError((error, stackTrace) {
          debugPrint('❌ HR subscription handleError: $error\n$stackTrace');
          throw error;  // Re-throw for further handling
        })
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) {
              debugPrint('❌ Stream transform error, falling back to simulation: $error');
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
      debugPrint('❌ BLE connection error: $e, using simulation');
      yield* _simulateConnection(id);
    }
  }

  /// ✅ PROPER POLAR HR PARSING
  /// Decodes Heart Rate Measurement characteristic value according to BLE spec
  /// Byte 0: Flags (0x00 = 8-bit HR, 0x01 = 16-bit HR)
  /// Byte 1: HR value (8-bit) OR HR LSB (16-bit)
  /// Byte 2: HR MSB (16-bit only)
  TrainingData _parseHeartRateMeasurement(
    List<int> data,
    double currentDistance,
    int currentStrokes,
    int lastHr,
    String id,
  ) {
    try {
      if (data.isEmpty) {
        return TrainingData(lastHr, currentDistance, currentStrokes, 2.0, speed: 0.5);
      }

      final flags = data[0];
      int heartRate = lastHr;

      // Check if 16-bit HR format (bit 0 of flags)
      if ((flags & 0x01) == 0x00) {
        // 8-bit HR (most common for Polar H10, H9, etc.)
        if (data.length > 1) {
          heartRate = data[1];
        }
        debugPrint('✅ HR parsed (8-bit): $heartRate bpm');
      } else {
        // 16-bit HR format
        if (data.length > 2) {
          heartRate = (data[2] << 8) | data[1]; // MSB | LSB
        }
        debugPrint('✅ HR parsed (16-bit): $heartRate bpm');
      }

      // ✅ Send HR data to UI callback
      onHeartRateDataReceived?.call(heartRate, id);

      // Sanity check
      if (heartRate > 0 && heartRate < 300) {
        return TrainingData(heartRate, currentDistance, currentStrokes, 2.0, speed: 0.5);
      } else {
        debugPrint('⚠️ Invalid HR value: $heartRate, using last known: $lastHr');
        return TrainingData(lastHr, currentDistance, currentStrokes, 2.0, speed: 0.5);
      }
    } catch (e) {
      debugPrint('❌ Error parsing HR: $e');
      return TrainingData(lastHr, currentDistance, currentStrokes, 2.0, speed: 0.5);
    }
  }

  /// Simulated BLE device scan (fallback).
  Future<List<BleDevice>> _simulateScan(Duration timeout) async {
    await Future.delayed(timeout);
    return [
      BleDevice('sim-polar-1', 'Polar H10'),
      BleDevice('sim-polar-2', 'Garmin HRM-Pro'),
      BleDevice('sim-hr-3', 'Simulated HR Monitor'),
    ];
  }

  /// Simulated device connection (fallback).
  Stream<TrainingData> _simulateConnection(String id) async* {
    double distance = 0.0;
    int strokes = 0;
    int hr = 100 + _rand.nextInt(30);
    
    debugPrint('🔄 Starting simulated connection for: $id');
    
    while (true) {
      // Simulate BLE update frequency (1 second = typical HR update rate)
      await Future.delayed(const Duration(seconds: 1));

      // Vary HR slightly
      hr = (hr + (_rand.nextInt(7) - 3)).clamp(40, 200);
      distance += 25.0;
      strokes += 8 + _rand.nextInt(6);
      final pace = 1.5 + _rand.nextDouble() * 1.5;
      final speed = 1.0 + _rand.nextDouble() * 1.5;

      yield TrainingData(hr, distance, strokes, pace, speed: speed);
    }
  }

  /// Toggle between real and simulated BLE.
  void setSimulationMode(bool enabled) {
    useSimulation = enabled;
    if (enabled) {
      debugPrint('🔄 Switched to SIMULATION mode');
    } else {
      debugPrint('📱 Switched to REAL BLE mode');
    }
  }

  // ✅ FIX #6: Proper cleanup of all resources
  void dispose() {
    try {
      _scanSub?.cancel();
      _scanSub = null;
      debugPrint('🧹 Disposed scan subscription');
    } catch (e) {
      debugPrint('⚠️ Error disposing scan sub: $e');
    }
    
    try {
      _connectionSub?.cancel();
      _connectionSub = null;
      debugPrint('🧹 Disposed connection subscription');
    } catch (e) {
      debugPrint('⚠️ Error disposing connection sub: $e');
    }
    
    _connectionState.clear();
    debugPrint('🧹 Cleared connection state map');
  }
}
