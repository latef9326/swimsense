import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../models/user_profile.dart';

/// State for user profile
class UserProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  UserProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Cubit for managing user profile (age, weight, height, gender, max HR)
class UserProfileCubit extends Cubit<UserProfileState> {
  late SharedPreferences _prefs;

  UserProfileCubit() : super(UserProfileState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadProfile();
    } catch (e) {
      debugPrint('❌ Error loading SharedPreferences: $e');
      emit(state.copyWith(error: 'Failed to load profile'));
    }
  }

  /// Load user profile from SharedPreferences
  void _loadProfile() {
    try {
      debugPrint('🔄 Loading profile from SharedPreferences...');
      // ✅ Use sensible defaults if no data exists
      final age = _prefs.getInt('user_age') ?? 25;
      final weight = _prefs.getDouble('user_weight') ?? 70.0;
      final height = _prefs.getDouble('user_height') ?? 175.0;
      final gender = _prefs.getString('user_gender') ?? 'male';
      final maxHr = _prefs.getInt('user_max_hr') ?? 185;

      final profile = UserProfile(
        age: age,
        weightKg: weight,
        heightCm: height,
        gender: gender,
        maxHeartRate: maxHr,
      );
      emit(state.copyWith(profile: profile));
      debugPrint('✅ User profile loaded: age=$age, weight=$weight kg');
    } catch (e) {
      debugPrint('❌ Error parsing profile: $e');
      emit(state.copyWith(error: 'Failed to parse profile'));
    }
  }

  /// Save user profile to SharedPreferences
  Future<void> saveProfile({
    required int age,
    required double weightKg,
    required double heightCm,
    required String gender,
    int? maxHeartRate,
  }) async {
    try {
      emit(state.copyWith(isLoading: true));

      await Future.wait([
        _prefs.setInt('user_age', age),
        _prefs.setDouble('user_weight', weightKg),
        _prefs.setDouble('user_height', heightCm),
        _prefs.setString('user_gender', gender.toLowerCase()),
        if (maxHeartRate != null) _prefs.setInt('user_max_hr', maxHeartRate),
      ]);

      final profile = UserProfile(
        age: age,
        weightKg: weightKg,
        heightCm: heightCm,
        gender: gender,
        maxHeartRate: maxHeartRate,
      );

      emit(state.copyWith(profile: profile, isLoading: false));
      debugPrint('✅ User profile saved: $profile');
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to save profile'));
    }
  }

  /// Update age
  Future<void> updateAge(int newAge) async {
    final profile = state.profile;
    if (profile != null) {
      await saveProfile(
        age: newAge,
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        gender: profile.gender,
        maxHeartRate: profile.maxHeartRate,
      );
    }
  }

  /// Update weight
  Future<void> updateWeight(double newWeight) async {
    final profile = state.profile;
    if (profile != null) {
      await saveProfile(
        age: profile.age,
        weightKg: newWeight,
        heightCm: profile.heightCm,
        gender: profile.gender,
        maxHeartRate: profile.maxHeartRate,
      );
    }
  }

  /// Get default profile if none saved (for fallback)
  static UserProfile getDefaultProfile() {
    return UserProfile(
      age: 30,
      weightKg: 75.0,
      heightCm: 180.0,
      gender: 'male',
    );
  }
}
