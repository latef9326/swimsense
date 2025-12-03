import 'package:swimsense/models/heart_rate_zones.dart';
import 'package:swimsense/models/swim_session.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'dart:math' as math;

/// Repository for calculating advanced swim analytics and performance metrics
class AnalyticsRepository {
  /// Calculate heart rate zones for a given max HR and session
  static List<HeartRateZone> calculateHeartRateZones(
    int maxHeartRate,
    SwimSession session,
  ) {
    final zones = StandardHeartRateZones.createZones(maxHeartRate: maxHeartRate);
    final hrData = session.heartRateData ?? [];

    if (hrData.isEmpty) return zones;

    // Reset zone metrics
    for (var zone in zones) {
      zone.timeInZoneMs = 0;
      zone.distanceInZone = 0.0;
      zone.caloriesInZone = 0.0;
      zone.averageHrInZone = 0;
    }

    // Calculate metrics per zone
    int totalTimeMs = session.elapsedTime * 1000;
    double timePerDataPoint = totalTimeMs / hrData.length;
    double distancePerDataPoint = session.distance / hrData.length;

    for (int i = 0; i < hrData.length; i++) {
      final hr = hrData[i];
      final zoneIndex = _getZoneIndex(zones, hr);
      if (zoneIndex >= 0) {
        zones[zoneIndex].timeInZoneMs += timePerDataPoint.toInt();
        zones[zoneIndex].distanceInZone += distancePerDataPoint;
        zones[zoneIndex].averageHrInZone =
            ((zones[zoneIndex].averageHrInZone * i) + hr) ~/ (i + 1);
      }
    }

    // Estimate calories (simplified: 1 cal per HR point per minute)
    for (var zone in zones) {
      zone.caloriesInZone = (zone.averageHrInZone * zone.timeInZoneMs) / 60000;
    }

    return zones;
  }

  static int _getZoneIndex(List<HeartRateZone> zones, int hr) {
    for (int i = 0; i < zones.length; i++) {
      if (hr >= zones[i].minBpm && hr <= zones[i].maxBpm) {
        return i;
      }
    }
    return -1;
  }

  /// Calculate SWOLF Score: time per 100m + stroke count per 100m
  /// Lower is better (more efficient)
  static double calculateSwolfScore(SwimSession session) {
    if (session.lapTimes == null || session.lapTimes!.isEmpty) {
      return 0.0;
    }

    // Assuming 25m pool, calculate strokes per 25m
    final totalLaps = session.lapTimes!.length;
    final strokesPer25m = session.totalStrokes / totalLaps;

    // Get average 100m time (4 laps of 25m)
    final avgLapTime = session.lapTimes!.reduce((a, b) => a + b) ~/ totalLaps;
    final avg100mTime = (avgLapTime * 4) / 1000; // convert to seconds

    // SWOLF = time per 100m + strokes per 100m
    final strokes100m = strokesPer25m * 4;
    return avg100mTime + strokes100m;
  }

  /// Calculate Lap Consistency Score: standard deviation of lap times
  /// Lower is better (more consistent)
  static double calculateLapConsistencyScore(SwimSession session) {
    if (session.lapTimes == null || session.lapTimes!.length < 2) {
      return 0.0;
    }

    final lapTimes = session.lapTimes!.map((ms) => ms.toDouble()).toList();
    final mean = lapTimes.reduce((a, b) => a + b) / lapTimes.length;

    final variance = lapTimes
        .map((time) => math.pow(time - mean, 2))
        .reduce((a, b) => a + b) /
        lapTimes.length;

    return math.sqrt(variance);
  }

  /// Analyze negative split: compare first half vs second half pace
  /// Positive value means slowed down (not ideal)
  static double calculatePaceDecay(SwimSession session) {
    if (session.lapTimes == null || session.lapTimes!.length < 2) {
      return 0.0;
    }

    final lapTimes = session.lapTimes!;
    final midpoint = lapTimes.length ~/ 2;

    final firstHalf =
        lapTimes.sublist(0, midpoint).reduce((a, b) => a + b) / midpoint;
    final secondHalf = lapTimes.sublist(midpoint).reduce((a, b) => a + b) /
        (lapTimes.length - midpoint);

    // Pace decay as percentage
    return ((secondHalf - firstHalf) / firstHalf) * 100;
  }

  /// Calculate Efficiency Index: distance / average heart rate
  /// Higher is better (more distance per heartbeat)
  static double calculateEfficiencyIndex(SwimSession session) {
    if (session.averageHeartRate == 0) return 0.0;
    return session.distance / session.averageHeartRate;
  }

  /// Calculate Swim Fitness Score: (distance × speed) / average HR
  /// Combines distance, speed, and cardiovascular response
  static double calculateSwimFitnessScore(SwimSession session) {
    if (session.averageHeartRate == 0 || session.averagePace == 0) return 0.0;

    // Speed in meters per minute
    final speedMperMin = 100 / session.averagePace * 1000 / 60;

    return (session.distance * speedMperMin) / session.averageHeartRate;
  }

  /// Estimate VO2 Max using Karvonen formula and heart rate response
  /// Simplified estimation based on training data
  static double estimateVO2Max({
    required int maxHr,
    required int restingHr,
    required double averageHr,
    required double pacePerMinute, // meters per minute
  }) {
    // Simplified VO2 Max estimation
    final hrReserve = maxHr - restingHr;
    final trainingIntensity = (averageHr - restingHr) / hrReserve;

    // VO2 Max estimate (mL/kg/min) - simplified formula
    final vo2Max = 15.0 + (trainingIntensity * 30.0);

    return vo2Max.clamp(20.0, 85.0);
  }

  /// Estimate lactate threshold HR (typically 85-90% of max HR)
  /// Can be estimated from training data patterns
  static int estimateLactateThresholdHr({
    required int maxHr,
    required List<int> recentMaxHrs,
  }) {
    // Typically 85-90% of max HR
    // Use recent hard efforts to refine estimate
    if (recentMaxHrs.isEmpty) {
      return (maxHr * 0.87).toInt();
    }

    final avgRecentMax = recentMaxHrs.reduce((a, b) => a + b) ~/ recentMaxHrs.length;
    return (avgRecentMax * 0.87).toInt();
  }

  /// Calculate heart rate recovery: HR drop in first 60 seconds after exercise
  /// Higher is better (indicates better fitness)
  static int calculateHeartRateRecovery(List<int> hrDataAtEnd) {
    if (hrDataAtEnd.length < 2) return 0;

    // Assuming roughly 1 data point per second
    final hr0s = hrDataAtEnd[0]; // at end of exercise
    final hr60s = hrDataAtEnd[math.min(60, hrDataAtEnd.length - 1)];

    return (hr0s - hr60s).abs();
  }

  /// Calculate Training Stress Score (TSS)
  /// TSS = (duration in minutes × intensity factor × FTP factor) × 100
  /// intensity factor = average intensity as percentage of threshold
  static double calculateTSS({
    required double durationMinutes,
    required int averageHeartRate,
    required int lactateThresholdHr,
  }) {
    // Simplified TSS calculation
    final intensityFactor = averageHeartRate / lactateThresholdHr;
    return (durationMinutes * intensityFactor * intensityFactor * 100) / 60;
  }

  /// Aggregate training load over last 7 days (Acute Training Load)
  static double calculateATL(List<TrainingMetrics> metricsLast7Days) {
    return metricsLast7Days.fold(0.0, (sum, m) => sum + m.trainingStressScore);
  }

  /// Aggregate training load over last 42 days (Chronic Training Load)
  static double calculateCTL(List<TrainingMetrics> metricsLast42Days) {
    return metricsLast42Days.fold(0.0, (sum, m) => sum + m.trainingStressScore);
  }

  /// Training Stress Balance: CTL - ATL
  /// Positive = fresh and ready for hard training
  /// Negative = fatigued, should recover
  static double calculateTSB(double atl, double ctl) {
    return ctl - atl;
  }

  /// Calculate fitness score (0-100) based on recent performance
  static double calculateFitnessScore({
    required double efficiencyIndex,
    required double swimFitnessScore,
    required int trainingStreak,
    required double vo2MaxEstimate,
    required int trainingSessionsThisMonth,
  }) {
    // Composite score from multiple factors
    double score = 0.0;

    // Efficiency contribution (0-30 points)
    score += math.min(30.0, efficiencyIndex * 10);

    // Fitness score contribution (0-30 points)
    score += math.min(30.0, swimFitnessScore * 5);

    // VO2 Max contribution (0-20 points)
    score += math.min(20.0, (vo2MaxEstimate / 60.0) * 20);

    // Consistency contribution (0-20 points)
    score += math.min(20.0, trainingStreak * 2);

    // Training volume (0-10 points, bonus for consistency)
    score += math.min(10.0, trainingSessionsThisMonth * 0.5);

    return score.clamp(0.0, 100.0);
  }

  /// Calculate consistency score based on training regularity
  static double calculateConsistencyScore(List<DateTime> trainingDates) {
    if (trainingDates.isEmpty) return 0.0;

    // Sort dates
    trainingDates.sort();

    // Calculate days between training sessions
    double totalGapDays = 0.0;
    for (int i = 1; i < trainingDates.length; i++) {
      final gap = trainingDates[i].difference(trainingDates[i - 1]).inDays;
      totalGapDays += gap.toDouble();
    }

    final averageGapDays = totalGapDays / (trainingDates.length - 1);

    // Score: ideal is every other day (2 days)
    // Goes down if gaps are too large or too small
    const idealGap = 2.0;
    final deviation = (averageGapDays - idealGap).abs();

    return math.max(0.0, 100.0 - (deviation * 10.0));
  }

  /// Calculate training streak: consecutive days with training
  static int calculateTrainingStreak(List<DateTime> trainingDates) {
    if (trainingDates.isEmpty) return 0;

    trainingDates.sort();

    int streak = 1;
    for (int i = trainingDates.length - 1; i > 0; i--) {
      final daysBetween =
          trainingDates[i].difference(trainingDates[i - 1]).inDays;
      if (daysBetween == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Compare two performance periods
  static PerformanceComparison comparePerformance({
    required List<SwimSession> currentPeriod,
    required List<SwimSession> previousPeriod,
    required String periodLabel,
  }) {
    final comparison = PerformanceComparison(
      startDate: currentPeriod.isNotEmpty
          ? currentPeriod.first.startTime
          : DateTime.now(),
      endDate:
          currentPeriod.isNotEmpty ? currentPeriod.last.endTime : DateTime.now(),
      period: periodLabel,
    );

    // Calculate current period metrics
    if (currentPeriod.isNotEmpty) {
      comparison.totalDistance =
          currentPeriod.fold(0.0, (sum, s) => sum + s.distance);
      comparison.trainingCount = currentPeriod.length;
      comparison.totalTimeMinutes = currentPeriod.fold(
          0, (sum, s) => sum + (s.elapsedTime ~/ 60));
      comparison.averageHeartRate =
          (currentPeriod.fold(0, (sum, s) => sum + s.averageHeartRate) /
                  currentPeriod.length)
              .toInt();
      comparison.averagePace =
          currentPeriod.fold(0.0, (sum, s) => sum + s.averagePace) /
              currentPeriod.length;
      comparison.averageSwolfScore =
          currentPeriod.fold(0.0, (sum, s) => sum + calculateSwolfScore(s)) /
              currentPeriod.length;
    }

    // Calculate changes vs previous period
    if (previousPeriod.isNotEmpty) {
      final prevDistance = previousPeriod.fold(0.0, (sum, s) => sum + s.distance);
      if (prevDistance > 0) {
        comparison.distanceChangePercent =
            ((comparison.totalDistance - prevDistance) / prevDistance) * 100;
      }

      final prevAvgPace = previousPeriod.fold(0.0, (sum, s) => sum + s.averagePace) /
          previousPeriod.length;
      if (prevAvgPace > 0) {
        comparison.paceChangePercent =
            ((comparison.averagePace - prevAvgPace) / prevAvgPace) * 100;
      }

      comparison.trainingCountChange = comparison.trainingCount - previousPeriod.length;
    }

    return comparison;
  }
}
