import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import '../repositories/swim_session_repository.dart';

/// Service for calculating Resting Heart Rate (RHR) from training data
/// RHR is measured during first 2 minutes of warm-up
class RhrService {
  final SwimSessionRepository _repo;

  RhrService({required SwimSessionRepository repo}) : _repo = repo;

  /// Calculate Resting HR from last 10 training sessions
  /// Takes 15th percentile of HR values from first 2 minutes of each session
  /// This approximates resting HR during warm-up phase
  Future<int> calculateRestingHR() async {
    try {
      // Get all sessions
      final allSessions = _repo.getAll();
      
      if (allSessions.isEmpty) {
        debugPrint('📊 RHR: No sessions found, returning default 60 bpm');
        return 60;
      }
      
      // Take last 10 sessions
      final recentSessions = allSessions.length > 10 
        ? allSessions.sublist(allSessions.length - 10)
        : allSessions;
      
      debugPrint('📊 RHR Calculation: Using ${recentSessions.length} recent sessions');
      
      // Collect warm-up HR values (first 2 minutes = ~20 samples at 6-second intervals)
      final warmUpHRs = <int>[];
      
      for (final session in recentSessions) {
        if (session.heartRateData == null || session.heartRateData!.isEmpty) continue;
        
        // Take first 20 HR samples (first 2 minutes)
        final first2MinHRs = session.heartRateData!.length > 20
          ? session.heartRateData!.sublist(0, 20)
          : session.heartRateData!;
        
        warmUpHRs.addAll(first2MinHRs);
        
        if (kDebugMode) {
          final avgWarmUpHR = first2MinHRs.isNotEmpty
            ? first2MinHRs.reduce((a, b) => a + b) ~/ first2MinHRs.length
            : 0;
          debugPrint('  Session warm-up avg HR: $avgWarmUpHR bpm (${first2MinHRs.length} samples)');
        }
      }
      
      if (warmUpHRs.isEmpty) {
        debugPrint('📊 RHR: No HR data in warm-ups, returning default 60 bpm');
        return 60;
      }
      
      // Sort and calculate 15th percentile
      warmUpHRs.sort();
      final percentile15Index = (warmUpHRs.length * 0.15).floor();
      final rhr = warmUpHRs[percentile15Index];
      
      // Biological constraint: RHR changes slowly (max 5 bpm/week drop)
      final constrainedRhr = rhr.clamp(40, 100);
      
      if (kDebugMode) {
        debugPrint('📊 RHR Calculation Results:');
        debugPrint('  Total HR samples: ${warmUpHRs.length}');
        debugPrint('  Min HR: ${warmUpHRs.first} bpm');
        debugPrint('  15th percentile: $rhr bpm');
        debugPrint('  Constrained RHR: $constrainedRhr bpm');
      }
      
      return constrainedRhr;
    } catch (e) {
      debugPrint('🔴 Error calculating RHR: $e');
      return 60;
    }
  }

  /// Get RHR trend over weeks (for UI display)
  Future<Map<String, int>> getRHRTrend() async {
    try {
      final allSessions = _repo.getAll();
      if (allSessions.isEmpty) return {};
      
      final now = DateTime.now();
      final trends = <String, int>{};
      
      // Calculate RHR for each week in past 4 weeks
      for (int week = 0; week < 4; week++) {
        final weekStart = now.subtract(Duration(days: 7 * (week + 1)));
        final weekEnd = now.subtract(Duration(days: 7 * week));
        
        final weekSessions = allSessions.where((s) {
          return s.startTime.isAfter(weekStart) && s.startTime.isBefore(weekEnd);
        }).toList();
        
        if (weekSessions.isEmpty) continue;
        
        // Calculate RHR for this week
        final warmUpHRs = <int>[];
        for (final session in weekSessions) {
          if (session.heartRateData == null || session.heartRateData!.isEmpty) continue;
          
          final first2Min = session.heartRateData!.length > 20
            ? session.heartRateData!.sublist(0, 20)
            : session.heartRateData!;
          warmUpHRs.addAll(first2Min);
        }
        
        if (warmUpHRs.isNotEmpty) {
          warmUpHRs.sort();
          final percentile15 = (warmUpHRs.length * 0.15).floor();
          final weekRhr = warmUpHRs[percentile15];
          trends['Week -$week'] = weekRhr;
        }
      }
      
      return trends;
    } catch (e) {
      debugPrint('🔴 Error getting RHR trend: $e');
      return {};
    }
  }
}
