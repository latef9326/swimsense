import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:swimsense/models/swim_session.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'package:swimsense/repositories/coaching_engine.dart';
import 'package:swimsense/repositories/analytics_repository.dart';

/// Coaching State Classes (defined first so Cubit can reference them)
abstract class CoachingState {}

class CoachingInitial extends CoachingState {}

class CoachingLoading extends CoachingState {}

class CoachingLoaded extends CoachingState {
  final List<TrainingRecommendation> recommendations;
  final WorkoutSuggestion nextWorkout;
  final FitnessIndicators fitnessState;

  CoachingLoaded({
    required this.recommendations,
    required this.nextWorkout,
    required this.fitnessState,
  });
}

class CoachingEmpty extends CoachingState {}

class CoachingError extends CoachingState {
  final String message;
  CoachingError(this.message);
}

/// Coaching Cubit - manages training recommendations and workout suggestions
class CoachingCubit extends Cubit<CoachingState> {
  final Box<SwimSession> sessionBox;

  CoachingCubit(this.sessionBox) : super(CoachingInitial());

  /// Load coaching recommendations based on current fitness
  Future<void> loadRecommendations() async {
    try {
      emit(CoachingLoading());

      final sessions = sessionBox.values.where((s) => !s.isPartial).toList();
      if (sessions.isEmpty) {
        emit(CoachingEmpty());
        return;
      }

      // Build fitness indicators
      final maxHr = sessions.fold(0, (prev, s) => s.maxHeartRate > prev ? s.maxHeartRate : prev);
      final fitness = FitnessIndicators(maxHeartRate: maxHr);

      // Calculate fitness metrics
      final lastSession = sessions.last;
      fitness.vo2MaxEstimate = AnalyticsRepository.estimateVO2Max(
        maxHr: fitness.maxHeartRate,
        restingHr: 60,
        averageHr: lastSession.averageHeartRate.toDouble(),
        pacePerMinute: (lastSession.distance / (lastSession.elapsedTime / 60)),
      );

      fitness.form = _calculateForm(sessions);
      fitness.fatigue = _calculateFatigue(sessions);
      fitness.fitnessScore = 70.0; // Placeholder

      // Create dummy training metrics list
      final trainingMetrics = <TrainingMetrics>[];

      // Generate recommendations
      final recommendations = CoachingEngine.generateRecommendations(
        fitness: fitness,
        recentSessions: sessions,
        trainingMetrics: trainingMetrics,
      );

      // Generate next workout suggestion
      final nextWorkout = CoachingEngine.suggestNextWorkout(
        fitness: fitness,
        recentSessions: sessions,
        lastWorkoutMinutesAgo: _getMinutesSinceLastWorkout(sessions),
      );

      emit(CoachingLoaded(
        recommendations: recommendations,
        nextWorkout: nextWorkout,
        fitnessState: fitness,
      ));
    } catch (e) {
      emit(CoachingError('Failed to load coaching data: $e'));
    }
  }

  /// Get a specific next workout based on fitness and preferences
  Future<WorkoutSuggestion> getNextWorkoutSuggestion() async {
    try {
      final sessions = sessionBox.values.where((s) => !s.isPartial).toList();
      if (sessions.isEmpty) {
        return WorkoutSuggestion(); // Return default
      }

      final maxHr = sessions.fold(0, (prev, s) => s.maxHeartRate > prev ? s.maxHeartRate : prev);
      final fitness = FitnessIndicators(maxHeartRate: maxHr);
      fitness.form = _calculateForm(sessions);
      fitness.fatigue = _calculateFatigue(sessions);

      return CoachingEngine.suggestNextWorkout(
        fitness: fitness,
        recentSessions: sessions,
        lastWorkoutMinutesAgo: _getMinutesSinceLastWorkout(sessions),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate predicted race pace
  Future<double> getPredictedRacePace({
    required int weeksUntilRace,
  }) async {
    try {
      final sessions = sessionBox.values.where((s) => !s.isPartial).toList();
      if (sessions.isEmpty) return 0.0;

      final lastSession = sessions.last;
      final maxHr = sessions.fold(0, (prev, s) => s.maxHeartRate > prev ? s.maxHeartRate : prev);
      final fitness = FitnessIndicators(maxHeartRate: maxHr);
      fitness.fitnessScore = 70.0;

      return CoachingEngine.calculateGoalRacePace(
        current100mPace: lastSession.averagePace,
        fitness: fitness,
        weeksUntilRace: weeksUntilRace,
      );
    } catch (e) {
      rethrow;
    }
  }

  double _calculateForm(List<SwimSession> sessions) {
    if (sessions.isEmpty) return 50.0;

    // Form based on recent sessions and consistency
    final last7Days = sessions.where((s) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      return s.startTime.isAfter(sevenDaysAgo);
    }).toList();

    // Higher form if consistent training
    double formScore = 50.0 + (last7Days.length * 5.0);

    // Decrease if average HR is very high (overtraining signal)
    if (last7Days.isNotEmpty) {
      final avgHr = last7Days.fold(0, (sum, s) => sum + s.averageHeartRate) ~/ last7Days.length;
      if (avgHr > 160) {
        formScore -= 20.0;
      }
    }

    return formScore.clamp(0.0, 100.0);
  }

  double _calculateFatigue(List<SwimSession> sessions) {
    if (sessions.isEmpty) return 50.0;

    // Fatigue based on training volume and intensity
    final last7Days = sessions.where((s) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      return s.startTime.isAfter(sevenDaysAgo);
    }).toList();

    double fatigueScore = 50.0;

    // More sessions = more fatigue
    fatigueScore += last7Days.length * 8.0;

    // High average HR = fatigue
    if (last7Days.isNotEmpty) {
      final avgHr = last7Days.fold(0, (sum, s) => sum + s.averageHeartRate) ~/ last7Days.length;
      if (avgHr > 160) {
        fatigueScore += 15.0;
      }
    }

    return fatigueScore.clamp(0.0, 100.0);
  }

  int _getMinutesSinceLastWorkout(List<SwimSession> sessions) {
    if (sessions.isEmpty) return 0;
    final lastWorkout = sessions.last;
    return DateTime.now().difference(lastWorkout.endTime).inMinutes;
  }
}
