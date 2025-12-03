import 'package:hive/hive.dart';

part 'training_metrics.g.dart';

/// Training Stress Score (TSS) and related metrics for periodization
@HiveType(typeId: 2)
class TrainingMetrics {
  @HiveField(0)
  DateTime date;

  @HiveField(1)
  int sessionId; // Reference to SwimSession

  /// Training Stress Score: intensity × duration × difficulty factor
  /// Range: 0-500+ (typically 50-200 per session)
  @HiveField(2)
  double trainingStressScore = 0.0;

  /// Acute Training Load: sum of TSS from last 7 days
  @HiveField(3)
  double acuteTrainingLoad = 0.0;

  /// Chronic Training Load: sum of TSS from last 42 days
  @HiveField(4)
  double chronicTrainingLoad = 0.0;

  /// Training Stress Balance: CTL - ATL
  /// Positive = rested, ready for hard training
  /// Negative = fatigued, need recovery
  @HiveField(5)
  double trainingStressBalance = 0.0;

  /// Efficiency Index: distance / average heart rate
  @HiveField(6)
  double efficiencyIndex = 0.0;

  /// Swim Fitness Score: (distance × speed) / average heart rate
  /// Higher = better fitness
  @HiveField(7)
  double swimFitnessScore = 0.0;

  /// SWOLF Score: time for length + number of strokes
  /// Lower is better (more efficient)
  @HiveField(8)
  double swolfScore = 0.0;

  /// Lap Consistency Score: standard deviation of lap times (lower is better)
  @HiveField(9)
  double lapConsistencyScore = 0.0;

  /// Pace decay: average pace of first half vs second half
  /// Positive = slowed down significantly
  @HiveField(10)
  double paceDayIndex = 0.0;

  /// Heart rate recovery: HR drop in first 60 seconds after exercise
  /// Higher is better (more fit)
  @HiveField(11)
  int heartRateRecovery = 0; // BPM

  /// Volume in meters for this session
  @HiveField(12)
  double sessionVolume = 0.0;

  /// Intensity as percentage of HRmax
  @HiveField(13)
  double intensityPercent = 0.0;

  /// Duration in minutes
  @HiveField(14)
  double durationMinutes = 0.0;

  TrainingMetrics({
    required this.date,
    required this.sessionId,
  });
}

/// Aggregated fitness and performance level indicators
@HiveType(typeId: 3)
class FitnessIndicators {
  @HiveField(0)
  late DateTime generatedAt;

  /// Estimated VO2 Max based on heart rate response
  /// Typical values: 35-60 mL/kg/min
  @HiveField(1)
  double vo2MaxEstimate = 0.0;

  /// Lactate Threshold Heart Rate (LTHR) - estimated
  /// Typically ~85-90% of HRmax
  @HiveField(2)
  int lactateThresholdHr = 0;

  /// Resting Heart Rate
  @HiveField(3)
  int restingHeartRate = 60;

  /// Maximum Heart Rate (measured)
  @HiveField(4)
  int maxHeartRate;

  /// Heart Rate Variability (HRV) - simplified measure of recovery
  @HiveField(5)
  int heartRateVariability = 0;

  /// Overall fitness level (0-100)
  @HiveField(6)
  double fitnessScore = 0.0;

  /// Consistency score: how regular are trainings (0-100)
  @HiveField(7)
  double consistencyScore = 0.0;

  /// Streak: consecutive days with training
  @HiveField(8)
  int trainingStreak = 0;

  /// Current form: 0-100 (100 = peak condition)
  @HiveField(9)
  double form = 50.0;

  /// Fatigue level: 0-100 (0 = fresh, 100 = exhausted)
  @HiveField(10)
  double fatigue = 50.0;

  /// Aerobic/Anaerobic ratio (higher = more aerobic training)
  @HiveField(11)
  double aerobicAnaerobiRatio = 2.0;

  /// Estimated 100m pace (seconds) - predicted based on current form
  @HiveField(12)
  double estimated100mPace = 0.0;

  /// Training age in months (how long tracking)
  @HiveField(13)
  int trainingAgeMonths = 0;

  FitnessIndicators({
    required this.maxHeartRate,
  }) {
    generatedAt = DateTime.now();
    restingHeartRate = 60;
  }
  String get fitnessLevel {
    if (fitnessScore < 40) return 'Beginner';
    if (fitnessScore < 60) return 'Intermediate';
    if (fitnessScore < 80) return 'Advanced';
    return 'Elite';
  }

  /// Gets form status for training recommendations
  String get formStatus {
    if (form > 75) return 'Peak - Push Hard';
    if (form > 50) return 'Good - Maintain';
    if (form > 25) return 'Fatigued - Recovery';
    return 'Exhausted - Rest Days';
  }
}

/// Performance comparison data for month-over-month or week-over-week analysis
@HiveType(typeId: 4)
class PerformanceComparison {
  @HiveField(0)
  DateTime startDate;

  @HiveField(1)
  DateTime endDate;

  @HiveField(2)
  String period; // "This Week", "This Month", etc.

  @HiveField(3)
  double totalDistance = 0.0;

  @HiveField(4)
  double averagePace = 0.0;

  @HiveField(5)
  int trainingCount = 0;

  @HiveField(6)
  int totalTimeMinutes = 0;

  @HiveField(7)
  int averageHeartRate = 0;

  @HiveField(8)
  double averageSwolfScore = 0.0;

  // Previous period comparison
  @HiveField(9)
  double distanceChangePercent = 0.0; // +5.2 for 5.2% increase

  @HiveField(10)
  double paceChangePercent = 0.0; // -2.1 for 2.1% improvement

  @HiveField(11)
  int trainingCountChange = 0;

  @HiveField(12)
  double fitnessScoreChange = 0.0;

  PerformanceComparison({
    required this.startDate,
    required this.endDate,
    required this.period,
  });

  String get distanceTrend => distanceChangePercent >= 0 ? '+${distanceChangePercent.toStringAsFixed(1)}%' : '${distanceChangePercent.toStringAsFixed(1)}%';

  String get paceTrend => paceChangePercent < 0 ? '${paceChangePercent.toStringAsFixed(1)}% faster' : '+${paceChangePercent.toStringAsFixed(1)}% slower';
}
