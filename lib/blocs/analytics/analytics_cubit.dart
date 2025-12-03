import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;
import 'package:swimsense/models/heart_rate_zones.dart';
import 'package:swimsense/models/swim_session.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'package:swimsense/repositories/analytics_repository.dart';

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

/// Analytics Cubit - manages computation and caching of advanced swimming metrics
class AnalyticsCubit extends Cubit<AnalyticsState> {
  final Box<SwimSession> sessionBox;
  
  // Cached values for performance
  late FitnessIndicators _currentFitness;
  late List<TrainingMetrics> _recentMetrics;
  late PerformanceComparison _weeklyComparison;
  late PerformanceComparison _monthlyComparison;

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

      // Calculate all metrics
      final fitnessScore = _calculateFitnessScore(sessions);
      final weeklyComp = _calculateWeeklyComparison(sessions);
      final monthlyComp = _calculateMonthlyComparison(sessions);
      final trainingLists = _aggregateTrainingMetrics(sessions);

      _currentFitness.fitnessScore = fitnessScore;
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

  @override
  Future<void> close() async {
    await super.close();
  }
}
