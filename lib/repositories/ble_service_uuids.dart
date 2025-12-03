/// BLE Service and Characteristic UUIDs for health/fitness devices.
/// Reference: https://www.bluetooth.com/specifications/gatt/services/
class BleServiceUuids {
  // Standardized Service UUIDs
  static const String heartRateService = '0000180D-0000-1000-8000-00805F9B34FB';
  static const String heartRateMeasurement = '00002A37-0000-1000-8000-00805F9B34FB';

  static const String cyclingPowerService = '00001818-0000-1000-8000-00805F9B34FB';
  static const String cyclingPowerMeasurement = '00002A63-0000-1000-8000-00805F9B34FB';

  static const String genericAccessService = '00001800-0000-1000-8000-00805F9B34FB';
  static const String deviceNameChar = '00002A00-0000-1000-8000-00805F9B34FB';

  // Custom service UUIDs (for swimming-specific devices)
  // These are placeholders; update with actual device UUIDs if known
  static const String customSwimmingService = 'A0000000-0000-0000-0000-000000000000';
  static const String customDistanceChar = 'A0000001-0000-0000-0000-000000000000';
  static const String customPaceChar = 'A0000002-0000-0000-0000-000000000000';
  static const String customStrokeChar = 'A0000003-0000-0000-0000-000000000000';

  // CCCD (Client Characteristic Configuration Descriptor) for notifications
  static const String clientCharacteristicConfig = '00002902-0000-1000-8000-00805F9B34FB';
}
