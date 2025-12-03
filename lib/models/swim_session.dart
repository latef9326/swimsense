import 'package:hive/hive.dart';

part 'swim_session.g.dart';

@HiveType(typeId: 0)
class SwimSession {
  @HiveField(0)
  late DateTime startTime;

  @HiveField(1)
  late DateTime endTime;

  @HiveField(2)
  int totalStrokes = 0;

  @HiveField(3)
  double distance = 0.0;

  @HiveField(4)
  int elapsedTime = 0;

  // New fields for BLE data
  @HiveField(5)
  int averageHeartRate = 0;

  @HiveField(6)
  int maxHeartRate = 0;

  @HiveField(7)
  double averagePace = 0.0; // pace per 100m

  @HiveField(8)
  int laps = 0;

  @HiveField(9)
  String swimStyle = 'unknown';

  @HiveField(10)
  int calories = 0;

  // Data for charts
  @HiveField(11)
  List<int>? heartRateData;

  @HiveField(12)
  List<double>? paceData;

  @HiveField(13)
  List<int>? strokeData;

  @HiveField(14)
  bool isPartial = false;

  /// Lap times stored as milliseconds per lap. Use [lapDurations] to get as Durations.
  @HiveField(15)
  List<int>? lapTimes;

  List<Duration> get lapDurations => lapTimes?.map((ms) => Duration(milliseconds: ms)).toList() ?? [];
}