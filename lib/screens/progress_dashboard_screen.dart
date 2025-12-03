import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// charts_flutter removed - using simple placeholders to avoid dependency issues
import 'package:swimsense/blocs/analytics/analytics_cubit.dart';
import 'package:swimsense/models/heart_rate_zones.dart';
import 'package:swimsense/models/training_metrics.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<AnalyticsCubit>().loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'HR Zones'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: BlocBuilder<AnalyticsCubit, AnalyticsState>(
        builder: (context, state) {
          if (state is AnalyticsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AnalyticsEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No training data yet'),
                  SizedBox(height: 8),
                  Text('Complete some sessions to see analytics'),
                ],
              ),
            );
          }
          if (state is AnalyticsError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is AnalyticsLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(state),
                _buildHRZonesTab(context, state),
                _buildTrendsTab(state),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildOverviewTab(AnalyticsLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fitness Score Card
          _buildFitnessScoreCard(state.fitness),
          const SizedBox(height: 16),

          // Key Indicators
          _buildKeyIndicatorsRow(state.fitness),
          const SizedBox(height: 16),

          // Weekly Comparison
          _buildComparisonCard('Weekly Performance', state.weeklyComparison),
          const SizedBox(height: 16),

          // Monthly Comparison
          _buildComparisonCard('Monthly Performance', state.monthlyComparison),
          const SizedBox(height: 16),

          // Form and Fatigue Indicators
          _buildFormFatigueCard(state.fitness),
        ],
      ),
    );
  }

  Widget _buildFitnessScoreCard(FitnessIndicators fitness) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fitness Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: fitness.fitnessScore / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getScoreColor(fitness.fitnessScore),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            fitness.fitnessScore.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'points',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level: ${fitness.fitnessLevel}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fitness.formStatus,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getFormStatusColor(fitness.form),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Streak: ${fitness.trainingStreak} days',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyIndicatorsRow(FitnessIndicators fitness) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                'VO₂ Max',
                fitness.vo2MaxEstimate.toStringAsFixed(1),
                'mL/kg/min',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'LTHR',
                '${fitness.lactateThresholdHr}',
                'BPM',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'Resting HR',
                '${fitness.restingHeartRate}',
                'BPM',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIndicatorCard(
                'Est. 100m',
                fitness.estimated100mPace.toStringAsFixed(1),
                'seconds',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'Consistency',
                fitness.consistencyScore.toStringAsFixed(0),
                'score',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIndicatorCard(
                'Age',
                '${fitness.trainingAgeMonths}',
                'months',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicatorCard(String label, String value, String unit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFatigueCard(FitnessIndicators fitness) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Training Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Form',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fitness.form / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fitness.form.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fatigue',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fitness.fatigue / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fitness.fatigue.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard(String title, PerformanceComparison comp) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow('Distance', '${comp.totalDistance.toStringAsFixed(0)}m',
                comp.distanceTrend),
            const SizedBox(height: 12),
            _buildComparisonRow('Avg Pace', '${comp.averagePace.toStringAsFixed(2)}s/100m',
                comp.paceTrend),
            const SizedBox(height: 12),
            _buildComparisonRow('Sessions', '${comp.trainingCount}',
                '${comp.trainingCountChange > 0 ? '+' : ''}${comp.trainingCountChange}'),
            const SizedBox(height: 12),
            _buildComparisonRow(
              'Avg HR',
              '${comp.averageHeartRate} BPM',
              '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, String change) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (change.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: change.contains('-') ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    color: change.contains('-') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHRZonesTab(BuildContext context, AnalyticsState state) {
    return FutureBuilder<List<HeartRateZone>>(
      future: context.read<AnalyticsCubit>().getHeartRateZones(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final zones = snapshot.data!;
        final totalTime = zones.fold(0, (sum, z) => sum + z.timeInZoneMs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Heart Rate Zone Distribution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Zone summary (pie chart)
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: zones.map((z) {
                      final value = totalTime > 0 ? z.timeInZoneMs.toDouble() : 0.0;
                      return PieChartSectionData(
                        color: z.color,
                        value: value,
                        title: totalTime > 0 ? '${((value / totalTime) * 100).toStringAsFixed(1)}%' : '',
                        radius: 52,
                        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Zone details
              for (var zone in zones) ...[
                _buildZoneDetailCard(zone, totalTime),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoneDetailCard(HeartRateZone zone, int totalTime) {
    final percentageOfTotal = totalTime > 0 ? (zone.timeInZoneMs / totalTime) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: zone.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        zone.description,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${zone.minBpm}-${zone.maxBpm} BPM'),
                Text('${percentageOfTotal.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${zone.distanceInZone.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Cals: ${zone.caloriesInZone.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Chart generation removed; using simple progress indicators instead.

  Widget _buildTrendsTab(AnalyticsLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics Over Time',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTrendChart(state.recentMetrics),
          const SizedBox(height: 24),
          const Text(
            'Recent Sessions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (var metric in state.recentMetrics.take(5)) ...[
            _buildMetricTile(metric),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<TrainingMetrics> metrics) {
    if (metrics.isEmpty) {
      return const Card(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No data available'),
      ));
    }

    final fitnessData = metrics
        .map((m) => FitnessData(m.date, m.swimFitnessScore))
        .toList();
    // Line chart of fitness scores
    final spots = <FlSpot>[];
    for (var i = 0; i < fitnessData.length; i++) {
      spots.add(FlSpot(i.toDouble(), fitnessData[i].score));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: _getScoreColor(spots.isNotEmpty ? spots.last.y : 0),
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: fitnessData.map((f) {
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(f.date.toString().split(' ')[0], style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(f.score.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Fitness Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(TrainingMetrics metric) {
    return Card(
      child: ListTile(
        title: Text(
          metric.date.toString().split('.').first,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Distance: ${metric.sessionVolume.toStringAsFixed(0)}m | '
          'Time: ${metric.durationMinutes.toStringAsFixed(1)} min | '
          'Avg HR: ${(metric.intensityPercent / 1.2).toStringAsFixed(0)} BPM',
        ),
        trailing: Text(
          'Score: ${metric.swimFitnessScore.toStringAsFixed(1)}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getFormStatusColor(double form) {
    if (form > 75) return Colors.green;
    if (form > 50) return Colors.blue;
    if (form > 25) return Colors.orange;
    return Colors.red;
  }
}

class FitnessData {
  final DateTime date;
  final double score;

  FitnessData(this.date, this.score);
}
