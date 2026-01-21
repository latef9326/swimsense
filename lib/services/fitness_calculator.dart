import 'dart:math';
import '../models/swim_session.dart';
import '../models/user_profile.dart';

/// Fitness calculation formulas for swim training
class FitnessCalculator {
  /// Calculate VO2 Max using modified Daniels formula for swimming
  /// VO2 = (-4.60 + 0.182258 * velocity + 0.000104 * velocity²) / (maxHR / restingHR)
  /// 
  /// [session] - Training session with distance and elapsed time
  /// [profile] - User profile with age, weight, maxHR, restingHR
  /// Returns: VO2 Max in ml/kg/min
  static double calculateVO2Max({
    required SwimSession session,
    required UserProfile profile,
    required int restingHR,
  }) {
    if (session.elapsedTime == 0 || session.distance == 0) {
      return 0.0;
    }

    // Calculate velocity in meters per minute
    final velocityMetersPerMin = session.distance / (session.elapsedTime / 60.0);

    // Daniels formula coefficients
    const baseVO2 = -4.60;
    const velocityCoeff = 0.182258;
    const velocitySqCoeff = 0.000104;

    // Calculate VO2 from velocity
    final vo2Raw = baseVO2 +
        (velocityCoeff * velocityMetersPerMin) +
        (velocitySqCoeff * pow(velocityMetersPerMin, 2));

    // Adjust for heart rate capacity (HR Reserve)
    final hrReserve = (profile.maxHeartRate - restingHR).toDouble();
    if (hrReserve <= 0) return 0.0;

    final vo2Max = vo2Raw / (hrReserve / 40.0); // Normalize to typical 40 bpm reserve

    // Clamp to realistic range (20-85 ml/kg/min for swimmers)
    return vo2Max.clamp(20.0, 85.0);
  }

  /// Calculate LTHR (Lactate Threshold Heart Rate)
  /// LTHR ≈ 85-88% of max HR (varies by training level)
  /// For swimmers, typically 87%
  /// 
  /// [profile] - User profile with maxHR
  /// [trainingLevel] - 'beginner', 'intermediate', 'advanced'
  /// Returns: LTHR in bpm
  static int calculateLTHR({
    required UserProfile profile,
    String trainingLevel = 'intermediate',
  }) {
    final percentage = switch (trainingLevel) {
      'beginner' => 0.85,
      'intermediate' => 0.87,
      'advanced' => 0.88,
      _ => 0.87,
    };

    return (profile.maxHeartRate * percentage).round();
  }

  /// Calculate overall Fitness Score (0-100)
  /// 40% VO2 Max + 30% Consistency + 20% Volume + 10% Frequency
  /// 
  /// [sessions] - List of completed training sessions
  /// [profile] - User profile
  /// [restingHR] - Resting heart rate from recent measurements
  /// Returns: Fitness score 0-100
  static double calculateFitnessScore({
    required List<SwimSession> sessions,
    required UserProfile profile,
    required int restingHR,
    int daysWindow = 30,
  }) {
    if (sessions.isEmpty) return 0.0;

    // Filter sessions from last N days
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: daysWindow));
    final windowSessions =
        sessions.where((s) => s.startTime.isAfter(windowStart)).toList();

    if (windowSessions.isEmpty) return 0.0;

    // 1. VO2 Max component (40%)
    final vo2Scores = windowSessions
        .map((s) =>
            calculateVO2Max(session: s, profile: profile, restingHR: restingHR))
        .toList();
    final avgVO2 = vo2Scores.fold(0.0, (a, b) => a + b) / vo2Scores.length;
    final vo2Score = (avgVO2 / 60.0 * 100).clamp(0.0, 100.0); // Normalize to 0-100

    // 2. Consistency component (30%) - variance of distances
    final distances = windowSessions.map((s) => s.distance.toDouble()).toList();
    final avgDistance =
        distances.fold(0.0, (a, b) => a + b) / distances.length;
    final variance = distances
        .map((d) => pow(d - avgDistance, 2))
        .fold(0.0, (a, b) => a + b as double) /
        distances.length;
    final stdev = sqrt(variance);
    final consistencyScore =
        100.0 - (stdev / avgDistance * 100).clamp(0.0, 100.0);

    // 3. Volume component (20%) - total distance
    final totalDistance =
        windowSessions.fold(0.0, (a, s) => a + s.distance.toDouble());
    final targetWeeklyVolume = 10000.0; // meters per week
    final weeklyAverage = totalDistance / (daysWindow / 7);
    final volumeScore =
        (weeklyAverage / targetWeeklyVolume * 100).clamp(0.0, 100.0);

    // 4. Frequency component (10%) - sessions per week
    final sessionFrequency = windowSessions.length / (daysWindow / 7);
    final targetFrequency = 4.0; // sessions per week
    final frequencyScore =
        (sessionFrequency / targetFrequency * 100).clamp(0.0, 100.0);

    // Weighted average
    final fitnessScore = (vo2Score * 0.40) +
        (consistencyScore * 0.30) +
        (volumeScore * 0.20) +
        (frequencyScore * 0.10);

    return fitnessScore.clamp(0.0, 100.0);
  }

  /// Get fitness level category
  /// 0-30: Beginner, 30-60: Intermediate, 60-100: Advanced
  static String getFitnessLevel(double score) {
    if (score < 30) return 'Beginner';
    if (score < 60) return 'Intermediate';
    return 'Advanced';
  }

  /// Get VO2 Max category (ml/kg/min)
  /// Based on Cooper standards for cardiorespiratory fitness
  static String getVO2MaxCategory(double vo2, {required String gender}) {
    final isFemale = gender.toLowerCase().startsWith('f');

    if (isFemale) {
      if (vo2 < 25) return 'Poor';
      if (vo2 < 31) return 'Fair';
      if (vo2 < 37) return 'Good';
      if (vo2 < 43) return 'Excellent';
      return 'Superior';
    } else {
      if (vo2 < 25) return 'Poor';
      if (vo2 < 35) return 'Fair';
      if (vo2 < 42) return 'Good';
      if (vo2 < 52) return 'Excellent';
      return 'Superior';
    }
  }
}
