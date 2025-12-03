import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models/swim_session.dart';
import 'models/heart_rate_zones.dart';
import 'models/training_metrics.dart';
import 'screens/main_navigation_screen.dart';
import 'repositories/ble_repository.dart';
import 'blocs/ble_connection/ble_connection_cubit.dart';
import 'blocs/analytics/analytics_cubit.dart';
import 'blocs/coaching/coaching_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(SwimSessionAdapter());
  Hive.registerAdapter(HeartRateZoneAdapter());
  Hive.registerAdapter(TrainingMetricsAdapter());
  Hive.registerAdapter(FitnessIndicatorsAdapter());
  Hive.registerAdapter(PerformanceComparisonAdapter());
  await Hive.openBox<SwimSession>('swim_sessions');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final BleRepository _bleRepo;
  late final BleConnectionCubit _bleCubit;
  late final AnalyticsCubit _analyticsCubit;
  late final CoachingCubit _coachingCubit;

  @override
  void initState() {
    super.initState();
    // single instances for lifecycle
    _bleRepo = BleRepository();
    _bleCubit = BleConnectionCubit(connectStream: _bleRepo.connectToDevice);

    final sessionBox = Hive.box<SwimSession>('swim_sessions');
    _analyticsCubit = AnalyticsCubit(sessionBox);
    _coachingCubit = CoachingCubit(sessionBox);
  }

  @override
  void dispose() {
    // close cubits and dispose resources once
    try {
      _bleCubit.close();
    } catch (_) {}
    try {
      _analyticsCubit.close();
    } catch (_) {}
    try {
      _coachingCubit.close();
    } catch (_) {}
    try {
      _bleRepo.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bleCubit),
        BlocProvider.value(value: _analyticsCubit),
        BlocProvider.value(value: _coachingCubit),
      ],
      child: MaterialApp(
        title: 'SwimSense',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainNavigationScreen(),
      ),
    );
  }
}
