import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/user_profile/user_profile_cubit.dart';
import '../blocs/analytics/analytics_cubit.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _maxHRController;
  String _selectedGender = 'male';

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _maxHRController = TextEditingController();

    // Load current values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<UserProfileCubit>();
      final profile = cubit.state.profile;
      if (profile != null) {
        _ageController.text = profile.age.toString();
        _weightController.text = profile.weightKg.toStringAsFixed(1);
        _heightController.text = profile.heightCm.toStringAsFixed(0);
        _maxHRController.text = profile.maxHeartRate.toString();
        _selectedGender = profile.gender;
      } else {
        // Set defaults
        _ageController.text = '30';
        _weightController.text = '75.0';
        _heightController.text = '180';
        _maxHRController.text = '190';
      }
    });
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _maxHRController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final cubit = context.read<UserProfileCubit>();
    final age = int.tryParse(_ageController.text) ?? 30;
    final weight = double.tryParse(_weightController.text) ?? 75.0;
    final height = double.tryParse(_heightController.text) ?? 180.0;
    final maxHR = int.tryParse(_maxHRController.text) ?? (220 - age);

    // Call saveProfile with individual parameters
    cubit.saveProfile(
      age: age,
      weightKg: weight,
      heightCm: height,
      gender: _selectedGender,
      maxHeartRate: maxHR,
    );
    
    // 🔧 KRYTYCZNE: Refresh analytics po zmianie profilu (VO2 Max/LTHR się zmienią)
    context.read<AnalyticsCubit>().loadAnalytics();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: BlocBuilder<UserProfileCubit, UserProfileState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Age
                        TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age (years)',
                            hintText: 'e.g., 30',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.cake),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Weight
                        TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            hintText: 'e.g., 75.5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.monitor_weight),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Height
                        TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Height (cm)',
                            hintText: 'e.g., 180',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.height),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Gender
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value ?? 'male';
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text('Female'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Max Heart Rate
                        TextField(
                          controller: _maxHRController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Heart Rate (bpm)',
                            hintText: 'e.g., 190',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.favorite),
                            helperText: 'Leave empty for auto-calculation (220 - age)',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Info card
                Card(
                  color: Colors.blue.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About These Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• Age is used to calculate max heart rate (default: 220 - age)\n'
                          '• Weight is used for calorie and VO2 calculations\n'
                          '• Height is used for BMI calculation\n'
                          '• Gender affects calorie formula coefficients\n'
                          '• Max Heart Rate overrides auto-calculation if set',
                          style: TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
