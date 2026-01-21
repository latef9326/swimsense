import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:swimsense/models/heart_rate_zones.dart';
import 'package:swimsense/models/swim_session.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'package:swimsense/repositories/analytics_repository.dart';
import 'package:swimsense/repositories/swim_session_repository.dart';
import 'package:swimsense/services/rhr_service.dart';
import 'package:swimsense/services/fitness_calculator.dart';
import 'package:swimsense/models/user_profile.dart';

/// State classes (defined first so Cubit can reference them)
abstract class AnalyticsState {}

class AnalyticsInitial extends AnalyticsState {}

class AnalyticsLoading extends AnalyticsState {}

class AnalyticsLoaded extends AnalyticsState {
  final FitnessIndicators fitness;
  final PerformanceComparison weeklyComparison;
  final PerformanceComparison monthlyComparison;
  final List<TrainingMetrics> recentMetrics;

  AnalyticsLoaded({
    required this.fitness,
    required this.weeklyComparison,
    required this.monthlyComparison,
    required this.recentMetrics,
  });
}

class AnalyticsEmpty extends AnalyticsState {}

class AnalyticsError extends AnalyticsState {
  final String message;
  AnalyticsError(this.message);
}

/// Detailed analytics for a single session
class SessionAnalytics {
  final SwimSession session;
  final List<HeartRateZone> hrZones;
  final double swolfScore;
  final double lapConsistency;
  final double paceDecay;
  final double efficiencyIndex;
  final double fitnessScore;
  final double vo2MaxEstimate;

  SessionAnalytics({
    required this.session,
    required this.hrZones,
    required this.swolfScore,
    required this.lapConsistency,
    required this.paceDecay,
    required this.efficiencyIndex,
    required this.fitnessScore,
    required this.vo2MaxEstimate,
  });
}

/// 🔧 Static method for background RHR calculation with delay
/// Uses Future.delayed instead of compute() because RhrService uses Hive (non-serializable)
Future<int> _calculateRhrWithDelay(RhrService service) async {
  await Future.delayed(Duration.zero); // Yield to UI thread
  return await service.calculateRestingHR();
}

/// Analytics Cubit - manages computation and caching of advanced swimming metrics
class AnalyticsCubit extends Cubit<AnalyticsState> {
  final Box<SwimSession> sessionBox;
  
  // Cached values for performance
  late FitnessIndicators _currentFitness;
  late List<TrainingMetrics> _recentMetrics;
  late PerformanceComparison _weeklyComparison;
  late PerformanceComparison _monthlyComparison;
  
  // ✅ Analytics tracking
  int _reconnectAttempts = 0;
  int _autoSavesTriggered = 0;
  int _deviceDisconnects = 0;

  AnalyticsCubit(this.sessionBox) : super(AnalyticsInitial()) {
    _initializeFitnessIndicators();
  }

  void _initializeFitnessIndicators() {
    final sessions = sessionBox.values.where((s) => !s.isPartial).toList();
    if (sessions.isEmpty) {
      _currentFitness = FitnessIndicators(maxHeartRate: 190);
      return;
    }

    final maxHr = sessions.fold(0, (prev, s) => math.max(prev, s.maxHeartRate));
    _currentFitness = FitnessIndicators(maxHeartRate: math.max(maxHr, 190));
  }

  /// Calculate and load all analytics
  Future<void> loadAnalytics() async {
    try {
      emit(AnalyticsLoading());

      final sessions = sessionBox.values.where((s) => !s.isPartial).toList();
      if (sessions.isEmpty) {
        emit(AnalyticsEmpty());
        return;
      }

      // 🆕 Load RHR from RhrService (replaces hardcoded 60 bpm)
      // 🔧 Use Future.delayed to avoid UI blocking (compute() fails with Hive non-serializable objects)
      final repo = SwimSessionRepository(); // Create repo instance for RHR calculation
      final rhrService = RhrService(repo: repo);
      final rhr = await _calculateRhrWithDelay(rhrService);
      _currentFitness.restingHeartRate = rhr;
      if (kDebugMode) {
        debugPrint('📊 RHR loaded from sessions: $rhr bpm');
      }

      // 🆕 Load user profile for VO2 Max and LTHR calculation
      UserProfile? userProfile;
      try {
        final prefs = await SharedPreferences.getInstance();
        final age = prefs.getInt('user_age') ?? 30;
        final weight = prefs.getDouble('user_weight') ?? 75.0;
        final height = prefs.getDouble('user_height') ?? 180.0;
        final gender = prefs.getString('user_gender') ?? 'male';
        final maxHR = prefs.getInt('user_max_hr') ?? (220 - age);
        
        userProfile = UserProfile(
          age: age,
          weightKg: weight,
          heightCm: height,
          gender: gender,
          maxHeartRate: maxHR,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  User profile not found, using defaults');
        }
      }

      // Calculate VO2 Max from latest session if profile exists
      if (userProfile != null && sessions.isNotEmpty) {
        final latestSession = sessions.last;
        try {
          final vo2 = FitnessCalculator.calculateVO2Max(
            session: latestSession,
            profile: userProfile,
            restingHR: rhr,
          );
          _currentFitness.vo2MaxEstimate = vo2;
          
          // Calculate LTHR
          final lthr = FitnessCalculator.calculateLTHR(
            profile: userProfile,
            trainingLevel: _determineTrainingLevel(sessions),
          );
          _currentFitness.lactateThresholdHr = lthr;
          
          if (kDebugMode) {
            debugPrint('📊 VO2 Max: ${vo2.toStringAsFixed(1)} mL/kg/min');
            debugPrint('📊 LTHR: $lthr bpm');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  Error calculating VO2 Max/LTHR: $e');
          }
        }
      } else {
        // Set defaults if no profile
        _currentFitness.vo2MaxEstimate = 0.0;
        _currentFitness.lactateThresholdHr = 0;
      }

      // Calculate all metrics
      final fitnessScore = _calculateFitnessScore(sessions);
      final weeklyComp = _calculateWeeklyComparison(sessions);
      final monthlyComp = _calculateMonthlyComparison(sessions);
      final trainingLists = _aggregateTrainingMetrics(sessions);

      // 🆕 Calculate Consistency Score from last 30 days of sessions
      final lastMonthSessions = sessions
          .where((s) => s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 30))))
          .toList();
      final consistencyScore = _calculateConsistencyScore(lastMonthSessions);

      _currentFitness.fitnessScore = fitnessScore;
      _currentFitness.consistencyScore = consistencyScore;
      _weeklyComparison = weeklyComp;
      _monthlyComparison = monthlyComp;
      _recentMetrics = trainingLists;

      emit(AnalyticsLoaded(
        fitness: _currentFitness,
        weeklyComparison: _weeklyComparison,
        monthlyComparison: _monthlyComparison,
        recentMetrics: _recentMetrics,
      ));
    } catch (e) {
      emit(AnalyticsError('Failed to load analytics: $e'));
    }
  }

  /// Get heart rate zones for the latest session
  Future<List<HeartRateZone>> getHeartRateZones() async {
    try {
      final sessions = sessionBox.values.toList();
      if (sessions.isEmpty) return [];

      final latestSession = sessions.last;
      return AnalyticsRepository.calculateHeartRateZones(
        _currentFitness.maxHeartRate,
        latestSession,
      );
    } catch (e) {
      emit(AnalyticsError('Failed to calculate HR zones: $e'));
      return [];
    }
  }

  /// Get detailed metrics for a specific session
  Future<SessionAnalytics> analyzeSession(SwimSession session) async {
    try {
      final zones = AnalyticsRepository.calculateHeartRateZones(
        _currentFitness.maxHeartRate,
        session,
      );

      final swolf = AnalyticsRepository.calculateSwolfScore(session);
      final consistency =
          AnalyticsRepository.calculateLapConsistencyScore(session);
      final paceDecay = AnalyticsRepository.calculatePaceDecay(session);
      final efficiency = AnalyticsRepository.calculateEfficiencyIndex(session);
      final fitnessScore = AnalyticsRepository.calculateSwimFitnessScore(session);
      final vo2 = AnalyticsRepository.estimateVO2Max(
        maxHr: _currentFitness.maxHeartRate,
        restingHr: _currentFitness.restingHeartRate,
        averageHr: session.averageHeartRate.toDouble(),
        pacePerMinute: (session.distance / (session.elapsedTime / 60)),
      );

      return SessionAnalytics(
        session: session,
        hrZones: zones,
        swolfScore: swolf,
        lapConsistency: consistency,
        paceDecay: paceDecay,
        efficiencyIndex: efficiency,
        fitnessScore: fitnessScore,
        vo2MaxEstimate: vo2,
      );
    } catch (e) {
      emit(AnalyticsError('Failed to analyze session: $e'));
      rethrow;
    }
  }

  /// 🆕 Get weekly performance metrics (last 7 days)
  Map<String, dynamic> getWeeklyMetrics() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    
    final weekSessions = sessionBox.values
        .where((s) => !s.isPartial && s.startTime.isAfter(weekAgo))
        .toList();

    if (weekSessions.isEmpty) {
      return {
        'totalDistance': 0.0,
        'averageDistance': 0.0,
        'sessionCount': 0,
        'totalDuration': 0,
        'averagePace': 0.0,
      };
    }

    final totalDistance = weekSessions.fold<double>(0, (a, s) => a + s.distance);
    final totalDuration =
        weekSessions.fold<int>(0, (a, s) => a + s.elapsedTime);

    return {
      'totalDistance': totalDistance,
      'averageDistance': totalDistance / weekSessions.length,
      'sessionCount': weekSessions.length,
      'totalDuration': totalDuration,
      'averagePace':
          totalDuration > 0 ? (totalDistance / (totalDuration / 60.0)) : 0.0,
    };
  }

  /// 🆕 Get monthly performance metrics (last 30 days)
  Map<String, dynamic> getMonthlyMetrics() {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    final monthSessions = sessionBox.values
        .where((s) => !s.isPartial && s.startTime.isAfter(monthAgo))
        .toList();

    if (monthSessions.isEmpty) {
      return {
        'totalDistance': 0.0,
        'averageDistance': 0.0,
        'sessionCount': 0,
        'totalDuration': 0,
        'averagePace': 0.0,
      };
    }

    final totalDistance =
        monthSessions.fold<double>(0, (a, s) => a + s.distance);
    final totalDuration =
        monthSessions.fold<int>(0, (a, s) => a + s.elapsedTime);

    return {
      'totalDistance': totalDistance,
      'averageDistance': totalDistance / monthSessions.length,
      'sessionCount': monthSessions.length,
      'totalDuration': totalDuration,
      'averagePace':
          totalDuration > 0 ? (totalDistance / (totalDuration / 60.0)) : 0.0,
    };
  }

  /// Determine training level based on number of sessions
  /// beginner: < 10 sessions, intermediate: 10-50, advanced: > 50
  String _determineTrainingLevel(List<SwimSession> sessions) {
    if (sessions.length < 10) return 'beginner';
    if (sessions.length < 50) return 'intermediate';
    return 'advanced';
  }

  /// 🆕 Calculate Consistency Score - how stable your training distances are
  /// Measures standard deviation of session distances (lower variance = higher consistency)
  /// Range: 0-100 (100 = perfect consistency, all sessions same distance)
  double _calculateConsistencyScore(List<SwimSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    if (sessions.length < 2) return 100.0; // Single session = perfect consistency by definition
    
    final distances = sessions.map((s) => s.distance.toDouble()).toList();
    final avgDistance = distances.fold<double>(0, (a, b) => a + b) / distances.length;
    
    if (avgDistance == 0) return 0.0;
    
    // Calculate standard deviation
    final variance = distances
        .map((d) => math.pow(d - avgDistance, 2))
        .fold<double>(0, (a, b) => a + b) / distances.length;
    final stdev = math.sqrt(variance);
    
    // Convert to consistency score: lower variance = higher score
    // 100 - (coefficient of variation * 100)
    final consistencyScore = 100.0 - (stdev / avgDistance * 100).clamp(0.0, 100.0);
    
    if (kDebugMode) {
      debugPrint('📊 Consistency Score: ${consistencyScore.toStringAsFixed(1)} '
                 '(avg distance: ${avgDistance.toStringAsFixed(1)}m, stdev: ${stdev.toStringAsFixed(1)}m)');
    }
    
    return consistencyScore;
  }

  double _calculateFitnessScore(List<SwimSession> sessions) {
    if (sessions.isEmpty) return 0.0;

    final lastSession = sessions.last;
    final lastMonthSessions = sessions
        .where((s) =>
            s.startTime.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .toList();

    final efficiencyIndex = AnalyticsRepository.calculateEfficiencyIndex(lastSession);
    final fitnessScore = AnalyticsRepository.calculateSwimFitnessScore(lastSession);
    final trainingDates = sessions.map((s) => s.startTime).toList();
    final streak = AnalyticsRepository.calculateTrainingStreak(trainingDates);

    return AnalyticsRepository.calculateFitnessScore(
      efficiencyIndex: efficiencyIndex,
      swimFitnessScore: fitnessScore,
      trainingStreak: streak,
      vo2MaxEstimate: _currentFitness.vo2MaxEstimate,
      trainingSessionsThisMonth: lastMonthSessions.length,
    );
  }

  PerformanceComparison _calculateWeeklyComparison(List<SwimSession> sessions) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    final currentWeek = sessions
        .where((s) => s.startTime.isAfter(weekAgo) && s.startTime.isBefore(now))
        .toList();
    final previousWeek = sessions
        .where((s) =>
            s.startTime.isAfter(twoWeeksAgo) && s.startTime.isBefore(weekAgo))
        .toList();

    return AnalyticsRepository.comparePerformance(
      currentPeriod: currentWeek,
      previousPeriod: previousWeek,
      periodLabel: 'This Week',
    );
  }

  PerformanceComparison _calculateMonthlyComparison(List<SwimSession> sessions) {
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    final twoMonthsAgo = DateTime(monthAgo.year, monthAgo.month - 1, monthAgo.day);

    final currentMonth = sessions
        .where((s) => s.startTime.isAfter(monthAgo) && s.startTime.isBefore(now))
        .toList();
    final previousMonth = sessions
        .where((s) =>
            s.startTime.isAfter(twoMonthsAgo) && s.startTime.isBefore(monthAgo))
        .toList();

    return AnalyticsRepository.comparePerformance(
      currentPeriod: currentMonth,
      previousPeriod: previousMonth,
      periodLabel: 'This Month',
    );
  }

  List<TrainingMetrics> _aggregateTrainingMetrics(List<SwimSession> sessions) {
    return sessions.map((session) {
      final metrics = TrainingMetrics(
        date: session.startTime,
        sessionId: session.hashCode,
      );

      metrics.sessionVolume = session.distance;
      metrics.durationMinutes = session.elapsedTime / 60;
      metrics.intensityPercent =
          (session.averageHeartRate / _currentFitness.maxHeartRate) * 100;
      metrics.swolfScore = AnalyticsRepository.calculateSwolfScore(session);
      metrics.lapConsistencyScore =
          AnalyticsRepository.calculateLapConsistencyScore(session);
      metrics.paceDayIndex = AnalyticsRepository.calculatePaceDecay(session);
      metrics.efficiencyIndex =
          AnalyticsRepository.calculateEfficiencyIndex(session);
      metrics.swimFitnessScore =
          AnalyticsRepository.calculateSwimFitnessScore(session);

      return metrics;
    }).toList();
  }

  /// ✅ Track reconnection attempt
  void trackReconnectAttempt(String deviceId, int attemptNumber) {
    _reconnectAttempts++;
    debugPrint('📊 Analytics: Reconnect attempt #$attemptNumber for $deviceId '
               '(total: $_reconnectAttempts)');
  }

  /// ✅ Track auto-save triggered
  void trackAutoSaveTriggered(String deviceId, String reason) {
    _autoSavesTriggered++;
    debugPrint('📊 Analytics: Auto-save triggered for $deviceId - $reason '
               '(total: $_autoSavesTriggered)');
  }

  /// ✅ Track device disconnect
  void trackDeviceDisconnect(String deviceId) {
    _deviceDisconnects++;
    debugPrint('📊 Analytics: Device disconnected: $deviceId '
               '(total: $_deviceDisconnects)');
  }

  /// ✅ Get reconnect analytics summary
  Map<String, int> getReconnectAnalytics() {
    return {
      'totalReconnectAttempts': _reconnectAttempts,
      'totalAutoSavesTriggered': _autoSavesTriggered,
      'totalDeviceDisconnects': _deviceDisconnects,
    };
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
