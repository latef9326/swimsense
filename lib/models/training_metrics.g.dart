// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_metrics.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrainingMetricsAdapter extends TypeAdapter<TrainingMetrics> {
  @override
  final int typeId = 2;

  @override
  TrainingMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final obj = TrainingMetrics(
      date: fields[0] as DateTime,
      sessionId: fields[1] as int,
    )
      ..trainingStressScore = fields[2] as double
      ..acuteTrainingLoad = fields[3] as double
      ..chronicTrainingLoad = fields[4] as double
      ..trainingStressBalance = fields[5] as double
      ..efficiencyIndex = fields[6] as double
      ..swimFitnessScore = fields[7] as double
      ..swolfScore = fields[8] as double
      ..lapConsistencyScore = fields[9] as double
      ..paceDayIndex = fields[10] as double
      ..heartRateRecovery = fields[11] as int
      ..sessionVolume = fields[12] as double
      ..intensityPercent = fields[13] as double
      ..durationMinutes = fields[14] as double;
    return obj;
  }

  @override
  void write(BinaryWriter writer, TrainingMetrics obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.sessionId)
      ..writeByte(2)
      ..write(obj.trainingStressScore)
      ..writeByte(3)
      ..write(obj.acuteTrainingLoad)
      ..writeByte(4)
      ..write(obj.chronicTrainingLoad)
      ..writeByte(5)
      ..write(obj.trainingStressBalance)
      ..writeByte(6)
      ..write(obj.efficiencyIndex)
      ..writeByte(7)
      ..write(obj.swimFitnessScore)
      ..writeByte(8)
      ..write(obj.swolfScore)
      ..writeByte(9)
      ..write(obj.lapConsistencyScore)
      ..writeByte(10)
      ..write(obj.paceDayIndex)
      ..writeByte(11)
      ..write(obj.heartRateRecovery)
      ..writeByte(12)
      ..write(obj.sessionVolume)
      ..writeByte(13)
      ..write(obj.intensityPercent)
      ..writeByte(14)
      ..write(obj.durationMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TrainingMetricsAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

class FitnessIndicatorsAdapter extends TypeAdapter<FitnessIndicators> {
  @override
  final int typeId = 3;

  @override
  FitnessIndicators read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final obj = FitnessIndicators(
      maxHeartRate: fields[4] as int,
    )
      ..generatedAt = fields[0] as DateTime
      ..vo2MaxEstimate = fields[1] as double
      ..lactateThresholdHr = fields[2] as int
      ..restingHeartRate = fields[3] as int
      ..heartRateVariability = fields[5] as int
      ..fitnessScore = fields[6] as double
      ..consistencyScore = fields[7] as double
      ..trainingStreak = fields[8] as int
      ..form = fields[9] as double
      ..fatigue = fields[10] as double
      ..aerobicAnaerobiRatio = fields[11] as double
      ..estimated100mPace = fields[12] as double
      ..trainingAgeMonths = fields[13] as int;
    return obj;
  }

  @override
  void write(BinaryWriter writer, FitnessIndicators obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.generatedAt)
      ..writeByte(1)
      ..write(obj.vo2MaxEstimate)
      ..writeByte(2)
      ..write(obj.lactateThresholdHr)
      ..writeByte(3)
      ..write(obj.restingHeartRate)
      ..writeByte(4)
      ..write(obj.maxHeartRate)
      ..writeByte(5)
      ..write(obj.heartRateVariability)
      ..writeByte(6)
      ..write(obj.fitnessScore)
      ..writeByte(7)
      ..write(obj.consistencyScore)
      ..writeByte(8)
      ..write(obj.trainingStreak)
      ..writeByte(9)
      ..write(obj.form)
      ..writeByte(10)
      ..write(obj.fatigue)
      ..writeByte(11)
      ..write(obj.aerobicAnaerobiRatio)
      ..writeByte(12)
      ..write(obj.estimated100mPace)
      ..writeByte(13)
      ..write(obj.trainingAgeMonths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FitnessIndicatorsAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

class PerformanceComparisonAdapter extends TypeAdapter<PerformanceComparison> {
  @override
  final int typeId = 4;

  @override
  PerformanceComparison read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final obj = PerformanceComparison(
      startDate: fields[0] as DateTime,
      endDate: fields[1] as DateTime,
      period: fields[2] as String,
    )
      ..totalDistance = fields[3] as double
      ..averagePace = fields[4] as double
      ..trainingCount = fields[5] as int
      ..totalTimeMinutes = fields[6] as int
      ..averageHeartRate = fields[7] as int
      ..averageSwolfScore = fields[8] as double
      ..distanceChangePercent = fields[9] as double
      ..paceChangePercent = fields[10] as double
      ..trainingCountChange = fields[11] as int
      ..fitnessScoreChange = fields[12] as double;
    return obj;
  }

  @override
  void write(BinaryWriter writer, PerformanceComparison obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.startDate)
      ..writeByte(1)
      ..write(obj.endDate)
      ..writeByte(2)
      ..write(obj.period)
      ..writeByte(3)
      ..write(obj.totalDistance)
      ..writeByte(4)
      ..write(obj.averagePace)
      ..writeByte(5)
      ..write(obj.trainingCount)
      ..writeByte(6)
      ..write(obj.totalTimeMinutes)
      ..writeByte(7)
      ..write(obj.averageHeartRate)
      ..writeByte(8)
      ..write(obj.averageSwolfScore)
      ..writeByte(9)
      ..write(obj.distanceChangePercent)
      ..writeByte(10)
      ..write(obj.paceChangePercent)
      ..writeByte(11)
      ..write(obj.trainingCountChange)
      ..writeByte(12)
      ..write(obj.fitnessScoreChange);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PerformanceComparisonAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
