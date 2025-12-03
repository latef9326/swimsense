import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'heart_rate_zones.g.dart';

/// Represents the 5 heart rate training zones based on % of HRmax
@HiveType(typeId: 1)
class HeartRateZone {
  @HiveField(0)
  final int zoneNumber; // 1-5

  @HiveField(1)
  final String name; // e.g., "Aerobic", "Anaerobic"

  @HiveField(2)
  final int minBpm;

  @HiveField(3)
  final int maxBpm;

  @HiveField(4)
  final double minPercentHRmax; // e.g., 0.50 for zone 1

  @HiveField(5)
  final double maxPercentHRmax; // e.g., 0.60 for zone 1

  @HiveField(6)
  final int colorValue;

  @HiveField(7)
  final String description;

  /// Time spent in this zone (milliseconds)
  @HiveField(8)
  int timeInZoneMs = 0;

  /// Distance covered in this zone (meters)
  @HiveField(9)
  double distanceInZone = 0.0;

  /// Total calories burned in this zone
  @HiveField(10)
  double caloriesInZone = 0.0;

  /// Average heart rate while in this zone
  @HiveField(11)
  int averageHrInZone = 0;

  HeartRateZone({
    required this.zoneNumber,
    required this.name,
    required this.minBpm,
    required this.maxBpm,
    required this.minPercentHRmax,
    required this.maxPercentHRmax,
    required this.colorValue,
    required this.description,
  });

  /// Percentage of total session time spent in this zone
  double get percentageOfSession => 0.0; // Calculated per session

  /// Returns a human-readable zone label
  String get label => 'Zone $zoneNumber: $name';

  /// Helper to get a Flutter `Color` from the stored integer value
  Color get color => Color(colorValue);

  @override
  String toString() => label;
}

/// Factory class to generate standard 5-zone model
class StandardHeartRateZones {
  /// Create 5 standard HR zones based on HRmax (e.g., 190 BPM)
  static List<HeartRateZone> createZones({required int maxHeartRate}) {
    return [
      HeartRateZone(
        zoneNumber: 1,
        name: 'Recovery',
        minBpm: (maxHeartRate * 0.50).toInt(),
        maxBpm: (maxHeartRate * 0.60).toInt(),
        minPercentHRmax: 0.50,
        maxPercentHRmax: 0.60,
        colorValue: 0xFF1E90FF, // Blue
        description: 'Very light, recovery focus',
      ),
      HeartRateZone(
        zoneNumber: 2,
        name: 'Aerobic',
        minBpm: (maxHeartRate * 0.60).toInt(),
        maxBpm: (maxHeartRate * 0.70).toInt(),
        minPercentHRmax: 0.60,
        maxPercentHRmax: 0.70,
        colorValue: 0xFF32CD32, // Green
        description: 'Light to moderate, sustainable',
      ),
      HeartRateZone(
        zoneNumber: 3,
        name: 'Tempo',
        minBpm: (maxHeartRate * 0.70).toInt(),
        maxBpm: (maxHeartRate * 0.80).toInt(),
        minPercentHRmax: 0.70,
        maxPercentHRmax: 0.80,
        colorValue: 0xFFFFD700, // Yellow
        description: 'Moderate intensity, aerobic capacity',
      ),
      HeartRateZone(
        zoneNumber: 4,
        name: 'Lactate Threshold',
        minBpm: (maxHeartRate * 0.80).toInt(),
        maxBpm: (maxHeartRate * 0.90).toInt(),
        minPercentHRmax: 0.80,
        maxPercentHRmax: 0.90,
        colorValue: 0xFFFF8C00, // Orange
        description: 'Hard, pushing limits',
      ),
      HeartRateZone(
        zoneNumber: 5,
        name: 'Maximum',
        minBpm: (maxHeartRate * 0.90).toInt(),
        maxBpm: maxHeartRate,
        minPercentHRmax: 0.90,
        maxPercentHRmax: 1.0,
        colorValue: 0xFFFF0000, // Red
        description: 'Maximum effort, sprinting',
      ),
    ];
  }
}
