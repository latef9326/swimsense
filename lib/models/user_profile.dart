/// User profile model for storing personal metrics needed for calorie/fitness calculations
class UserProfile {
  final int age; // years
  final double weightKg; // kilograms
  final double heightCm; // centimeters (for BMI calculation)
  final String gender; // 'male' or 'female' (affects calorie formula)
  final int maxHeartRate; // bpm (default: 220 - age)

  UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    this.gender = 'male',
    int? maxHeartRate,
  }) : maxHeartRate = maxHeartRate ?? (220 - age);

  /// Get calorie coefficient for Keytel formula (adjusts for gender)
  /// Men: -55.0969, Women: -20.4022
  double get calorieCoefficient {
    return gender.toLowerCase() == 'female' ? -20.4022 : -55.0969;
  }

  /// Weight coefficient in Keytel formula
  /// Men: 0.1988, Women: 0.1988 (same)
  static const double weightCoefficient = 0.1988;

  /// Age coefficient in Keytel formula
  /// Men: 0.2017, Women: 0.2017 (same)
  static const double ageCoefficient = 0.2017;

  /// HR coefficient in Keytel formula (same for both)
  static const double hrCoefficient = 0.6309;

  @override
  String toString() => 'UserProfile(age: $age, weight: ${weightKg}kg, height: ${heightCm}cm, gender: $gender, maxHR: $maxHeartRate)';
}
