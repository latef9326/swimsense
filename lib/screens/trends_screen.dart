import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../repositories/swim_session_repository.dart';
import '../models/swim_session.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  late SwimSessionRepository _repository;
  late Future<List<SwimSession>> _futureData;

  @override
  void initState() {
    super.initState();
    _repository = SwimSessionRepository();
    _futureData = Future.value(_repository.getAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distance Trends')),
      body: FutureBuilder<List<SwimSession>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No training data yet'),
                  SizedBox(height: 8),
                  Text('Complete some sessions to see trends'),
                ],
              ),
            );
          }

          final sessions = snapshot.data!;
          final chartData = _prepareLast30DaysData(sessions);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distance Over Time (Last 30 Days)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildDistanceChart(chartData),
                const SizedBox(height: 24),
                const Text(
                  'Weekly Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildWeeklySummary(sessions),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Prepare data for last 30 days
  List<Map<String, dynamic>> _prepareLast30DaysData(List<SwimSession> sessions) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Filter sessions from last 30 days
    final filteredSessions = sessions
        .where((s) => s.startTime.isAfter(thirtyDaysAgo))
        .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Group by date and sum distances
    final Map<String, double> dateDistance = {};
    for (var session in filteredSessions) {
      final date = DateFormat('dd MMM').format(session.startTime);
      dateDistance[date] = (dateDistance[date] ?? 0) + session.distance;
    }

    // Create list of 30 days (even if no data)
    final result = <Map<String, dynamic>>[];
    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('dd MMM').format(date);
      result.add({
        'date': dateKey,
        'distance': dateDistance[dateKey] ?? 0.0,
        'dayIndex': i,
      });
    }

    return result;
  }

  Widget _buildDistanceChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No data available'),
        ),
      );
    }

    // Calculate max for Y-axis with 10% padding
    final maxDistance =
        data.map((d) => d['distance'] as double).fold(0.0, (a, b) => a > b ? a : b);
    final yMax = (maxDistance * 1.1).toInt() + 1;

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['distance'] as double)));
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            SizedBox(
              height: 280,
              child: ClipRect(
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: yMax > 0 ? yMax / 5 : 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[300],
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}m',
                              style: const TextStyle(fontSize: 11),
                            );
                          },
                          reservedSize: 45,
                          interval: (yMax / 5).ceilToDouble(),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < data.length) {
                              // Show every 7th day to avoid overlap
                              if (index % 7 == 0 || index == data.length - 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    data[index]['date'].toString(),
                                    style: const TextStyle(fontSize: 9),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                            }
                            return const Text('');
                          },
                          reservedSize: 50,
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!),
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    barGroups: List.generate(
                      data.length,
                      (index) => BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: (data[index]['distance'] as double).clamp(0.0, yMax.toDouble()),
                            color: Colors.blue,
                            width: 5,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    ),
                    maxY: yMax.toDouble(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildChartLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            color: Colors.blue,
          ),
          const SizedBox(width: 8),
          const Text('Daily Distance (meters)'),
        ],
      ),
    );
  }

  Widget _buildWeeklySummary(List<SwimSession> allSessions) {
    final now = DateTime.now();
    final weeks = <Map<String, dynamic>>[];

    for (int weekOffset = 3; weekOffset >= 0; weekOffset--) {
      final weekStart =
          now.subtract(Duration(days: now.weekday - 1 + (weekOffset * 7)));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final weekSessions = allSessions
          .where((s) =>
              s.startTime.isAfter(weekStart) &&
              s.startTime.isBefore(weekEnd.add(const Duration(days: 1))))
          .toList();

      final totalDistance =
          weekSessions.fold<double>(0, (sum, s) => sum + s.distance);
      final sessionCount = weekSessions.length;

      weeks.add({
        'week': 'Week of ${DateFormat('MMM dd').format(weekStart)}',
        'distance': totalDistance,
        'sessions': sessionCount,
      });
    }

    return Column(
      children: weeks
          .map(
            (week) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          week['week'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('${week['sessions']} sessions'),
                      ],
                    ),
                    Text(
                      '${(week['distance'] as double).toStringAsFixed(0)} m',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
