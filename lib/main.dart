import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'models/swim_session.dart';
import 'models/heart_rate_zones.dart';
import 'models/training_metrics.dart';
import 'screens/main_navigation_screen.dart';
import 'widgets/water_background.dart';
import 'repositories/ble_repository_improved.dart';
import 'repositories/swim_session_repository.dart';
import 'blocs/ble_connection/ble_connection_cubit.dart';
import 'blocs/analytics/analytics_cubit.dart';
import 'blocs/coaching/coaching_cubit.dart';
import 'blocs/live_training/live_training_cubit.dart';

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
  late final LiveTrainingCubit _liveTrainingCubit;

  @override
  void initState() {
    super.initState();
    // single instances for lifecycle
    _bleRepo = BleRepository();
    
    // ✅ PHASE 1: Create LiveTrainingCubit FIRST (bleCubit optional now)
    // 🎯 LOG #1
    debugPrint('🔧 main.dart initState: Creating _liveTrainingCubit...');
    final sessionBox = Hive.box<SwimSession>('swim_sessions');
    final sessionRepository = SwimSessionRepository();
    _liveTrainingCubit = LiveTrainingCubit(
      bleCubit: null,  // Will be connected to BleConnectionCubit below
      sessionRepo: sessionRepository,
    );
    debugPrint('✅ main.dart initState: _liveTrainingCubit created: $_liveTrainingCubit');
    
    // ✅ PHASE 2: Create Analytics & Coaching Cubits
    _analyticsCubit = AnalyticsCubit(sessionBox);
    _coachingCubit = CoachingCubit(sessionBox);
    
    // ✅ PHASE 3: Create BleConnectionCubit (WITHOUT LiveTrainingCubit initially to avoid race condition)
    // 🎯 LOG #2
    debugPrint('🔧 main.dart initState: Creating _bleCubit...');
    _bleCubit = BleConnectionCubit(
      connectStream: _bleRepo.connectToDevice,
      bleRepository: _bleRepo,
      analyticsCubit: _analyticsCubit,
    );
    debugPrint('✅ main.dart initState: _bleCubit created: $_bleCubit');
    
    // ✅ PHASE 4: NOW safely attach LiveTrainingCubit to BleConnectionCubit
    // 🎯 LOG #3 - This is the CRITICAL FIX to prevent race condition
    debugPrint('🔧 main.dart initState: Calling setLiveTrainingCubit() on _bleCubit...');
    _bleCubit.setLiveTrainingCubit(_liveTrainingCubit);
    debugPrint('✅ main.dart initState: setLiveTrainingCubit() complete - HR callbacks should now work!');
    
    // ✅ PHASE 5: Set the BleConnectionCubit reference in LiveTrainingCubit
    _liveTrainingCubit.setBleCubit(_bleCubit);
  }

  @override
  void dispose() {
    // close cubits and dispose resources once
    try {
      _bleCubit.close();
    } catch (_) {}
    try {
      _liveTrainingCubit.close();
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
        BlocProvider.value(value: _liveTrainingCubit),
        BlocProvider.value(value: _bleCubit),
        BlocProvider.value(value: _analyticsCubit),
        BlocProvider.value(value: _coachingCubit),
      ],
      child: MaterialApp(
        title: 'SwimSense',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF00796B),
            onPrimary: Colors.white,
            secondary: Color(0xFF26C6DA),
            onSecondary: Colors.white,
            error: Colors.red,
            onError: Colors.white,
            background: Color(0xFFe0f7fa),
            onBackground: Colors.black,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            foregroundColor: Colors.black,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 6,
            ),
          ),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: Colors.black87,
                displayColor: Colors.black87,
              ),
        ),
        home: WaterBackground(child: const MainNavigationScreen()),
      ),
    );
  }
}
