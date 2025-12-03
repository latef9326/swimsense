// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swim_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SwimSessionAdapter extends TypeAdapter<SwimSession> {
  @override
  final int typeId = 0;

  @override
  SwimSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SwimSession()
      ..startTime = fields[0] as DateTime
      ..endTime = fields[1] as DateTime
      ..totalStrokes = fields[2] as int
      ..distance = fields[3] as double
      ..elapsedTime = fields[4] as int
      ..averageHeartRate = fields[5] as int
      ..maxHeartRate = fields[6] as int
      ..averagePace = fields[7] as double
      ..laps = fields[8] as int
      ..swimStyle = fields[9] as String
      ..calories = fields[10] as int
      ..heartRateData = (fields[11] as List?)?.cast<int>()
      ..paceData = (fields[12] as List?)?.cast<double>()
      ..strokeData = (fields[13] as List?)?.cast<int>()
      ..isPartial = fields[14] as bool? ?? false
      ..lapTimes = (fields[15] as List?)?.cast<int>();
  }

  @override
  void write(BinaryWriter writer, SwimSession obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.endTime)
      ..writeByte(2)
      ..write(obj.totalStrokes)
      ..writeByte(3)
      ..write(obj.distance)
      ..writeByte(4)
      ..write(obj.elapsedTime)
      ..writeByte(5)
      ..write(obj.averageHeartRate)
      ..writeByte(6)
      ..write(obj.maxHeartRate)
      ..writeByte(7)
      ..write(obj.averagePace)
      ..writeByte(8)
      ..write(obj.laps)
      ..writeByte(9)
      ..write(obj.swimStyle)
      ..writeByte(10)
      ..write(obj.calories)
      ..writeByte(11)
      ..write(obj.heartRateData)
      ..writeByte(12)
      ..write(obj.paceData)
      ..writeByte(13)
      ..write(obj.strokeData)
      ..writeByte(14)
      ..write(obj.isPartial)
      ..writeByte(15)
      ..write(obj.lapTimes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwimSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
