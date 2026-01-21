import '../models/swim_session.dart';
import 'dart:math' as math;

/// Training Status Calculator using TRIMP (Training IMPulse) and EMA (Exponential Moving Average)
/// 
/// Model: Form = Fitness - Fatigue
/// - TRIMP = Heart Rate * Duration (in minutes)
/// - Fatigue uses 7-day EMA (α=0.5)
/// - Fitness accumulates over 42-day window
/// - Form = 0-100%, where:
///   * <30% = Tired/Fatigued (needs rest)
///   * 30-70% = Normal (good for training)
///   * >70% = Fresh/Ready (peak performance)
class TrainingStatusCalculator {
  /// Calculate TRIMP for a single session
  /// TRIMP = Heart Rate * Duration (in minutes)
  /// For swim training: often scaled by HR intensity zone
  /// 
  /// [session] - Training session with HR data and duration
  /// Returns: TRIMP value (higher = more intense)
  static double calculateTRIMP({
    required SwimSession session,
    required int restingHR,
    required int maxHR,
  }) {
    if (session.elapsedTime == 0 || session.averageHeartRate == null) {
      return 0.0;
    }

    final avgHR = session.averageHeartRate!.toDouble();
    final durationMinutes = session.elapsedTime / 60.0;

    // Calculate HR Reserve ratio
    final hrReserve = (maxHR - restingHR).toDouble();
    if (hrReserve <= 0) return 0.0;

    final hrIntensity = (avgHR - restingHR) / hrReserve;

    // TRIMP with intensity weighting
    // Female coefficient: 0.86, Male: 1.67 (for swimming)
    const maleCoeff = 1.67; // Using male default
    final trimp = durationMinutes * avgHR * hrIntensity * maleCoeff;

    return trimp.clamp(0, 5000); // Cap at 5000 TRIMP max per session
  }

  /// Calculate Fatigue using Exponential Moving Average (EMA)
  /// EMA heavily weights recent sessions
  /// 
  /// [sessions] - Ordered list of sessions (oldest to newest)
  /// [alpha] - Smoothing factor (0-1), default 0.5 for 7-day window
  /// Returns: Fatigue 0-100
  static double calculateFatigue({
    required List<SwimSession> sessions,
    required int restingHR,
    required int maxHR,
    double alpha = 0.5,
  }) {
    if (sessions.isEmpty) return 0.0;

    // Calculate TRIMP for last 7 days
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentSessions = sessions
        .where((s) => s.startTime.isAfter(sevenDaysAgo))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (recentSessions.isEmpty) return 0.0;

    // Calculate EMA of TRIMP
    double ema = 0.0;
    for (var session in recentSessions) {
      final trimp = calculateTRIMP(
        session: session,
        restingHR: restingHR,
        maxHR: maxHR,
      );
      ema = (trimp * alpha) + (ema * (1 - alpha));
    }

    // Normalize: 0 TRIMP = 0% fatigue, 300 TRIMP = 100% fatigue
    final fatigue = (ema / 300.0 * 100).clamp(0.0, 100.0);

    return fatigue;
  }

  /// Calculate Fitness using 42-day accumulation window
  /// Fitness = sum of all TRIMP values over 42 days
  /// 
  /// [sessions] - All training sessions
  /// Returns: Fitness score (0-5000+, unbounded)
  static double calculateFitness({
    required List<SwimSession> sessions,
    required int restingHR,
    required int maxHR,
  }) {
    if (sessions.isEmpty) return 0.0;

    final now = DateTime.now();
    final fortyTwoDaysAgo = now.subtract(const Duration(days: 42));

    final windowSessions = sessions
        .where((s) => s.startTime.isAfter(fortyTwoDaysAgo))
        .toList();

    double totalFitness = 0.0;
    for (var session in windowSessions) {
      final trimp = calculateTRIMP(
        session: session,
        restingHR: restingHR,
        maxHR: maxHR,
      );
      totalFitness += trimp;
    }

    // Normalize to 0-100 scale (assuming max ~2500 TRIMP over 42 days)
    final normalizedFitness =
        math.min(100.0, (totalFitness / 2500.0) * 100);

    return normalizedFitness;
  }

  /// Calculate Form (Readiness for training)
  /// Form = Fitness - Fatigue
  /// 
  /// Form interpretation:
  /// - <30%: Over-tired, recovery needed
  /// - 30-70%: Normal, ready for training
  /// - >70%: Fresh and ready, good time for peak efforts
  static double calculateForm({
    required double fitness,
    required double fatigue,
  }) {
    // Form = Fitness - Fatigue, clamped to 0-100
    final form = fitness - fatigue;
    return form.clamp(-50.0, 100.0);
  }

  /// Get training status description
  static String getTrainingStatus(double form) {
    if (form > 70) {
      return 'Peak Form - Ready for peak efforts';
    } else if (form > 40) {
      return 'Normal - Good for training';
    } else if (form > 0) {
      return 'Fatigued - Light training recommended';
    } else {
      return 'Over-trained - Rest day needed';
    }
  }

  /// Get recommendation based on form
  static String getRecommendation(double form) {
    if (form > 70) {
      return '💪 Perfect time for speed work or long distance';
    } else if (form > 40) {
      return '✅ Good for regular training, moderate intensity';
    } else if (form > 0) {
      return '⚠️ Consider easy recovery swim or rest';
    } else {
      return '🔴 Rest day recommended - high fatigue';
    }
  }

  /// Calculate acute:chronic workload ratio (ACWR)
  /// ACWR = (Acute Load / Chronic Load)
  /// - <0.8: Under-training
  /// - 0.8-1.3: Optimal (lowest injury risk)
  /// - >1.3: Over-training (higher injury risk)
  static double calculateACWR({
    required List<SwimSession> sessions,
    required int restingHR,
    required int maxHR,
  }) {
    if (sessions.isEmpty) return 0.0;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourtyDaysAgo = now.subtract(const Duration(days: 42));

    // Acute: last 7 days
    final acuteSessions = sessions
        .where((s) => s.startTime.isAfter(sevenDaysAgo))
        .toList();
    final acuteLoad = acuteSessions.fold<double>(
      0,
      (sum, s) => sum +
          calculateTRIMP(
            session: s,
            restingHR: restingHR,
            maxHR: maxHR,
          ),
    );

    // Chronic: 35-42 days ago (comparing to previous 4 weeks)
    final chronicStart = fourtyDaysAgo;
    final chronicEnd = sevenDaysAgo;
    final chronicSessions = sessions
        .where((s) =>
            s.startTime.isAfter(chronicStart) &&
            s.startTime.isBefore(chronicEnd))
        .toList();
    final chronicLoad = chronicSessions.fold<double>(
      0,
      (sum, s) => sum +
          calculateTRIMP(
            session: s,
            restingHR: restingHR,
            maxHR: maxHR,
          ),
    );

    if (chronicLoad == 0) return 0.0;
    return acuteLoad / chronicLoad;
  }

  /// Get training load status based on ACWR
  static String getTrainingLoadStatus(double acwr) {
    if (acwr < 0.8) {
      return 'Under-training';
    } else if (acwr <= 1.3) {
      return 'Optimal load';
    } else if (acwr <= 1.5) {
      return 'Elevated load';
    } else {
      return 'High risk - over-training';
    }
  }
}
