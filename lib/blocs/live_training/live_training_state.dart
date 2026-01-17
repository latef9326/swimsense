import '../../repositories/ble_repository_improved.dart';
import '../../models/swim_session.dart';

enum TrainingStatus { notStarted, running, paused, finished }

class LiveTrainingState {
  final TrainingStatus status;
  final Duration elapsedTime;
  // Millisecond-precision fields (added for high-resolution timer)
  final int elapsedTimeMillis;
  final int currentTimeMillis;
  final TrainingData? currentData;
  final List<TrainingData> dataHistory;
  final SwimSession? completedSession;
  final SwimSession? lastAutoSavedPartial;
  final int poolLengthMeters;
  final List<int> lapTimesMillis; // stored as milliseconds per lap
  final int lastLapStartElapsedMs; // elapsedTime in ms when last lap was started
  final bool autoLapEnabled;

  LiveTrainingState({
    this.status = TrainingStatus.notStarted,
    this.elapsedTime = Duration.zero,
    this.elapsedTimeMillis = 0,
    this.currentTimeMillis = 0,
    this.currentData,
    List<TrainingData>? dataHistory,
    this.completedSession,
    this.lastAutoSavedPartial,
    this.poolLengthMeters = 25,
    List<int>? lapTimesMillis,
    this.lastLapStartElapsedMs = 0,
    this.autoLapEnabled = false,
  }) : dataHistory = dataHistory ?? const [],
      lapTimesMillis = lapTimesMillis ?? const [];

  LiveTrainingState copyWith({
    TrainingStatus? status,
    Duration? elapsedTime,
    int? elapsedTimeMillis,
    int? currentTimeMillis,
    TrainingData? currentData,
    List<TrainingData>? dataHistory,
    SwimSession? completedSession,
    SwimSession? lastAutoSavedPartial,
    int? poolLengthMeters,
    List<int>? lapTimesMillis,
    int? lastLapStartElapsedMs,
    bool? autoLapEnabled,
  }) {
    return LiveTrainingState(
      status: status ?? this.status,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      elapsedTimeMillis: elapsedTimeMillis ?? this.elapsedTimeMillis,
      currentTimeMillis: currentTimeMillis ?? this.currentTimeMillis,
      currentData: currentData ?? this.currentData,
      dataHistory: dataHistory ?? this.dataHistory,
      completedSession: completedSession ?? this.completedSession,
      lastAutoSavedPartial: lastAutoSavedPartial ?? this.lastAutoSavedPartial,
      poolLengthMeters: poolLengthMeters ?? this.poolLengthMeters,
      lapTimesMillis: lapTimesMillis ?? this.lapTimesMillis,
      lastLapStartElapsedMs: lastLapStartElapsedMs ?? this.lastLapStartElapsedMs,
      autoLapEnabled: autoLapEnabled ?? this.autoLapEnabled,
    );
  }
  
  List<Duration> get lapDurations => lapTimesMillis.map((ms) => Duration(milliseconds: ms)).toList();
  int get lapCount => lapTimesMillis.length;
  Duration get currentLapTime {
    final elapsedMs = elapsedTimeMillis > 0 ? elapsedTimeMillis : elapsedTime.inMilliseconds;
    return Duration(milliseconds: elapsedMs - lastLapStartElapsedMs);
  }
}
