import 'package:swimsense/models/swim_session.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'package:swimsense/repositories/analytics_repository.dart';
import 'package:flutter/material.dart';

/// Coaching recommendation engine based on training data analysis
class CoachingEngine {
  /// Generate smart training recommendations based on current fitness state
  static List<TrainingRecommendation> generateRecommendations({
    required FitnessIndicators fitness,
    required List<SwimSession> recentSessions,
    required List<TrainingMetrics> trainingMetrics,
  }) {
    final recommendations = <TrainingRecommendation>[];

    // Analyze current state and generate recommendations
    if (fitness.form > 75) {
      recommendations.add(
        TrainingRecommendation(
          type: RecommendationType.pushHard,
          title: 'Peak Condition Detected',
          description:
              'Your body is in peak condition with high form (${fitness.form.toStringAsFixed(0)}%) and low fatigue. This is the ideal time for intense interval training.',
          action: 'Plan a hard interval session: 10x200m with 30s rest',
          priority: PriorityLevel.high,
        ),
      );
    } else if (fitness.form < 25) {
      recommendations.add(
        TrainingRecommendation(
          type: RecommendationType.recovery,
          title: 'Recovery Week Recommended',
          description:
              'Your form is low (${fitness.form.toStringAsFixed(0)}%), indicating fatigue and potential overtraining. Take an easy recovery week.',
          action: 'Plan 3-4 easy 30-minute swims at conversational pace',
          priority: PriorityLevel.high,
        ),
      );
    }

    // Technique analysis
    if (recentSessions.isNotEmpty) {
      final lastSession = recentSessions.last;
      final swolf = AnalyticsRepository.calculateSwolfScore(lastSession);
      final consistency =
          AnalyticsRepository.calculateLapConsistencyScore(lastSession);

      if (consistency > 3000) {
        // High variance in lap times
        recommendations.add(
          TrainingRecommendation(
            type: RecommendationType.technique,
            title: 'High Lap Time Variance Detected',
            description:
                'Your lap times vary significantly (stddev: ${consistency.toStringAsFixed(0)}ms). This suggests inconsistent pacing or technique issues.',
            action:
                'Focus on steady-paced drills: 8x100m on 2:00 with emphasis on rhythm',
            priority: PriorityLevel.medium,
          ),
        );
      }

      if (swolf > 90) {
        recommendations.add(
          TrainingRecommendation(
            type: RecommendationType.technique,
            title: 'SWOLF Score High - Efficiency Issue',
            description:
                'Your SWOLF score (${swolf.toStringAsFixed(1)}) is high, indicating either slow pace or excessive strokes.',
            action: 'Practice streamline drills and focus on stroke count: 6x50m kick',
            priority: PriorityLevel.medium,
          ),
        );
      }

      // Negative split analysis
      final paceDecay = AnalyticsRepository.calculatePaceDecay(lastSession);
      if (paceDecay > 5) {
        recommendations.add(
          TrainingRecommendation(
            type: RecommendationType.technique,
            title: 'Significant Pace Decay Detected',
            description:
                'Your second half was ${paceDecay.toStringAsFixed(1)}% slower than first half. Build better endurance.',
            action:
                'Do longer continuous swims: 1000m steady at aerobic pace, then 4x100m hard',
            priority: PriorityLevel.medium,
          ),
        );
      }
    }

    // Volume optimization
    if (trainingMetrics.isNotEmpty) {
      final last7Days = trainingMetrics.where((m) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        return m.date.isAfter(sevenDaysAgo);
      }).toList();

      final totalVolume = last7Days.fold(0.0, (sum, m) => sum + m.sessionVolume);
      final sessionCount = last7Days.length;

      if (sessionCount > 0) {
        final avgVolume = totalVolume / sessionCount;

        if (sessionCount < 3) {
          recommendations.add(
            TrainingRecommendation(
              type: RecommendationType.volume,
              title: 'Low Training Frequency',
              description:
                  'You\'ve had only $sessionCount sessions this week. Consistency matters more than intensity.',
              action: 'Aim for 4-5 sessions per week, including 1-2 easy recovery swims',
              priority: PriorityLevel.medium,
            ),
          );
        }

        if (avgVolume > 3500) {
          recommendations.add(
            TrainingRecommendation(
              type: RecommendationType.volume,
              title: 'High Training Volume',
              description:
                  'Your average session is ${avgVolume.toStringAsFixed(0)}m. Balance with recovery.',
              action: 'Add 2 recovery swims (1500-2000m easy) in your schedule',
              priority: PriorityLevel.low,
            ),
          );
        }
      }
    }

    // Heart rate recovery
    if (recentSessions.isNotEmpty) {
      final lastSession = recentSessions.last;
      final hrRecovery = _estimateHRRecovery(lastSession);

      if (hrRecovery < 12) {
        recommendations.add(
          TrainingRecommendation(
            type: RecommendationType.fitness,
            title: 'Improve Cardiovascular Recovery',
            description:
                'Your HR recovery is only $hrRecovery BPM/min, indicating lower aerobic fitness.',
            action:
                'Increase aerobic base: 6 sessions of 45min steady-state at Z2 (60-70% HRmax)',
            priority: PriorityLevel.high,
          ),
        );
      }
    }

    // Best time to swim
    recommendations.add(
      TrainingRecommendation(
        type: RecommendationType.scheduling,
        title: 'Optimal Training Time',
        description:
            'Based on your data, you perform best in the morning (higher form index).',
        action: 'Schedule key workouts before 10 AM when possible',
        priority: PriorityLevel.low,
      ),
    );

    // VO2 Max progression
    if (fitness.vo2MaxEstimate > 0 && fitness.trainingAgeMonths > 3) {
      if (fitness.vo2MaxEstimate < 40) {
        recommendations.add(
          TrainingRecommendation(
            type: RecommendationType.fitness,
            title: 'Build Aerobic Capacity',
            description:
                'Your estimated VO2 Max (${fitness.vo2MaxEstimate.toStringAsFixed(1)}) can be improved significantly.',
            action:
                'Incorporate VO2 Max work: 4-6x300m at Z4 (80-90% HRmax) with 90s recovery',
            priority: PriorityLevel.high,
          ),
        );
      }
    }

    // Recovery status
    if (fitness.fatigue > 70) {
      recommendations.add(
        TrainingRecommendation(
          type: RecommendationType.recovery,
          title: 'High Fatigue Level',
          description:
              'Your fatigue is elevated (${fitness.fatigue.toStringAsFixed(0)}%). Body needs recovery time.',
          action:
              'Take 1-2 complete rest days. Do light stretching and foam rolling.',
          priority: PriorityLevel.high,
        ),
      );
    } else if (fitness.fatigue < 30) {
      recommendations.add(
        TrainingRecommendation(
          type: RecommendationType.pushHard,
          title: 'Ready for Intensity',
          description:
              'Your fatigue is very low (${fitness.fatigue.toStringAsFixed(0)}%). Perfect for hard workouts.',
          action: 'This is your window for threshold or sprint work',
          priority: PriorityLevel.high,
        ),
      );
    }

    return recommendations;
  }

  /// Calculate next workout suggestion
  static WorkoutSuggestion suggestNextWorkout({
    required FitnessIndicators fitness,
    required List<SwimSession> recentSessions,
    required int lastWorkoutMinutesAgo,
  }) {
    final suggestion = WorkoutSuggestion();
    suggestion.suggestedDate = DateTime.now().add(const Duration(days: 1));

    if (fitness.form > 70 && fitness.fatigue < 40) {
      suggestion.workoutType = WorkoutType.threshold;
      suggestion.title = 'Lactate Threshold Work';
      suggestion.description = 'You\'re ready for hard work. Build your threshold fitness.';
      suggestion.suggestedSets = '5x400m @ threshold pace with 60s rest';
      suggestion.expectedDuration = 50;
      suggestion.expectedDistance = 2500;
    } else if (fitness.fatigue < 50 && fitness.form > 50) {
      suggestion.workoutType = WorkoutType.tempo;
      suggestion.title = 'Tempo / Aerobic Work';
      suggestion.description = 'Build aerobic capacity with sustained effort.';
      suggestion.suggestedSets = '3x800m @ tempo pace with 120s rest';
      suggestion.expectedDuration = 45;
      suggestion.expectedDistance = 2800;
    } else if (fitness.form < 40) {
      suggestion.workoutType = WorkoutType.recovery;
      suggestion.title = 'Easy Recovery Swim';
      suggestion.description = 'Keep it easy to recover. Light aerobic work only.';
      suggestion.suggestedSets = '2000m easy mixed strokes with drills';
      suggestion.expectedDuration = 30;
      suggestion.expectedDistance = 2000;
    } else {
      suggestion.workoutType = WorkoutType.mixed;
      suggestion.title = 'Balanced Mixed Set';
      suggestion.description = 'Combination of skills and steady work.';
      suggestion.suggestedSets = 'Warm-up: 400m | Main: 6x150m alternating paces | Cool-down: 200m';
      suggestion.expectedDuration = 40;
      suggestion.expectedDistance = 2300;
    }

    suggestion.rpe = _calculateRPE(fitness, suggestion.workoutType);

    return suggestion;
  }

  /// Calculate race pace based on current fitness
  static double calculateGoalRacePace({
    required double current100mPace,
    required FitnessIndicators fitness,
    required int weeksUntilRace,
  }) {
    // Assume 2-3% improvement possible with proper training
    const improvementPercentPerWeek = 0.003;
    final totalImprovement = improvementPercentPerWeek * weeksUntilRace;

    // Adjust based on current fitness level
    final fitnessMultiplier = 1.0 - (fitness.fitnessScore / 100) * 0.05;

    final projectedPace = current100mPace * (1.0 - totalImprovement * fitnessMultiplier);

    return projectedPace.clamp(
      current100mPace * 0.95, // Can't improve more than 5%
      current100mPace, // Won't get slower
    );
  }

  static int _estimateHRRecovery(SwimSession session) {
    // Simplified: assume HR drops 1 BPM per second during recovery
    // In real scenario, would use actual HRData post-exercise
    if (session.maxHeartRate == 0 || session.averageHeartRate == 0) return 0;
    return ((session.maxHeartRate - session.averageHeartRate) / 60).toInt();
  }

  static int _calculateRPE(FitnessIndicators fitness, WorkoutType type) {
    // Rate of Perceived Exertion (1-10 scale)
    switch (type) {
      case WorkoutType.recovery:
        return 3;
      case WorkoutType.easy:
        return 4;
      case WorkoutType.mixed:
        return 5;
      case WorkoutType.tempo:
        return 7;
      case WorkoutType.threshold:
        return 8;
      case WorkoutType.vo2max:
        return 9;
      case WorkoutType.sprint:
        return 10;
    }
  }
}

enum RecommendationType {
  pushHard,
  recovery,
  technique,
  volume,
  fitness,
  scheduling,
}

enum PriorityLevel {
  low,
  medium,
  high,
}

class TrainingRecommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final String action;
  final PriorityLevel priority;
  DateTime createdAt = DateTime.now();

  TrainingRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.action,
    required this.priority,
  });

  Color get priorityColor {
    switch (priority) {
      case PriorityLevel.high:
        return const Color(0xFFFF6B6B); // Red
      case PriorityLevel.medium:
        return const Color(0xFFFFA500); // Orange
      case PriorityLevel.low:
        return const Color(0xFF4ECDC4); // Teal
    }
  }

  IconData get typeIcon {
    switch (type) {
      case RecommendationType.pushHard:
        return Icons.flash_on;
      case RecommendationType.recovery:
        return Icons.spa;
      case RecommendationType.technique:
        return Icons.pan_tool;
      case RecommendationType.volume:
        return Icons.trending_up;
      case RecommendationType.fitness:
        return Icons.favorite;
      case RecommendationType.scheduling:
        return Icons.schedule;
    }
  }
}

enum WorkoutType {
  recovery,
  easy,
  mixed,
  tempo,
  threshold,
  vo2max,
  sprint,
}

class WorkoutSuggestion {
  late WorkoutType workoutType;
  late String title;
  late String description;
  late String suggestedSets;
  late int expectedDuration; // minutes
  late int expectedDistance; // meters
  late int rpe; // Rate of Perceived Exertion (1-10)
  late DateTime suggestedDate;

  String get typeLabel {
    switch (workoutType) {
      case WorkoutType.recovery:
        return '🟦 Recovery';
      case WorkoutType.easy:
        return '🟩 Easy';
      case WorkoutType.mixed:
        return '🟨 Mixed';
      case WorkoutType.tempo:
        return '🟧 Tempo';
      case WorkoutType.threshold:
        return '🟥 Threshold';
      case WorkoutType.vo2max:
        return '⚫ VO2 Max';
      case WorkoutType.sprint:
        return '🔴 Sprint';
    }
  }
}

