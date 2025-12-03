import 'package:hive_flutter/hive_flutter.dart';

import '../models/swim_session.dart';

class SwimSessionRepository {
  static const _boxName = 'swim_sessions';

  Box<SwimSession> get _box => Hive.box<SwimSession>(_boxName);

  List<SwimSession> getAll() => _box.values.toList();

  Future<void> add(SwimSession session) async => await _box.add(session);

  Future<void> deleteAt(int index) async => await _box.deleteAt(index);

  Future<void> clear() async => await _box.clear();
}
