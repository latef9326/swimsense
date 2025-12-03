// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heart_rate_zones.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HeartRateZoneAdapter extends TypeAdapter<HeartRateZone> {
  @override
  final int typeId = 1;

  @override
  HeartRateZone read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final obj = HeartRateZone(
      zoneNumber: fields[0] as int,
      name: fields[1] as String,
      minBpm: fields[2] as int,
      maxBpm: fields[3] as int,
      minPercentHRmax: fields[4] as double,
      maxPercentHRmax: fields[5] as double,
      colorValue: fields[6] as int,
      description: fields[7] as String,
    )
      ..timeInZoneMs = fields[8] as int
      ..distanceInZone = fields[9] as double
      ..caloriesInZone = fields[10] as double
      ..averageHrInZone = fields[11] as int;
    return obj;
  }

  @override
  void write(BinaryWriter writer, HeartRateZone obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.zoneNumber)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.minBpm)
      ..writeByte(3)
      ..write(obj.maxBpm)
      ..writeByte(4)
      ..write(obj.minPercentHRmax)
      ..writeByte(5)
      ..write(obj.maxPercentHRmax)
      ..writeByte(6)
      ..write(obj.colorValue)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.timeInZoneMs)
      ..writeByte(9)
      ..write(obj.distanceInZone)
      ..writeByte(10)
      ..write(obj.caloriesInZone)
      ..writeByte(11)
      ..write(obj.averageHrInZone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HeartRateZoneAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
