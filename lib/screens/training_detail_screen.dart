import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

import '../models/swim_session.dart';

class TrainingDetailScreen extends StatefulWidget {
  final SwimSession session;

  const TrainingDetailScreen({super.key, required this.session});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  String? _hoverText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (widget.session.isPartial) const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 8),
          Text(widget.session.isPartial ? 'Partial Session' : 'Session Details'),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  _statTile('Avg HR', '${widget.session.averageHeartRate} bpm'),
                  _statTile('Max HR', '${widget.session.maxHeartRate} bpm'),
                  _statTile('Distance', '${widget.session.distance.toStringAsFixed(0)} m'),
                  _statTile('Avg Pace', '${widget.session.averagePace.toStringAsFixed(2)} min/100m'),
                  _statTile('Strokes', '${widget.session.totalStrokes}'),
                  _statTile('Calories', '${widget.session.calories} kcal'),
                  _statTile('Duration', _formatDuration(widget.session.elapsedTime)),
                  _statTile('Date', _formatDate(widget.session.startTime)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.session.heartRateData != null && widget.session.heartRateData!.isNotEmpty) ...[
              const Text('Heart Rate over time'),
              const SizedBox(height: 8),
              SizedBox(height: 240, child: _buildLineChartHR()),
              const SizedBox(height: 8),
              if (_hoverText != null) Padding(padding: const EdgeInsets.only(top:6.0, bottom:6.0), child: Text(_hoverText!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
            if (widget.session.paceData != null && widget.session.paceData!.isNotEmpty) ...[
              const Text('Pace over time'),
              const SizedBox(height: 8),
              SizedBox(height: 240, child: _buildLineChartPace()),
              const SizedBox(height: 8),
              if (_hoverText != null) Padding(padding: const EdgeInsets.only(top:6.0, bottom:6.0), child: Text(_hoverText!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ],
            const SizedBox(height: 12),

            // LAP TIMES SECTION
            if (widget.session.lapTimes != null && widget.session.lapTimes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(children: [Icon(Icons.timer), SizedBox(width: 8), Text('Czasy okrążeń', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final lapMs = widget.session.lapTimes ?? [];
                final lapDurations = lapMs.map((ms) => Duration(milliseconds: ms)).toList();
                final count = lapDurations.length;
                // compute stats
                final fastestMs = lapMs.reduce(min);
                final slowestMs = lapMs.reduce(max);
                final avgMs = (lapMs.reduce((a, b) => a + b) / count).round();
                // std dev in seconds
                final mean = avgMs.toDouble();
                final variance = lapMs.map((e) => pow(e - mean, 2)).reduce((a, b) => a + b) / count;
                final stdSec = sqrt(variance) / 1000.0;

                final fastestIndex = lapMs.indexOf(fastestMs);
                final slowestIndex = lapMs.indexOf(slowestMs);

                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('$count okrążeń', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: min(180, count * 40).toDouble(),
                    child: ListView.builder(
                      itemCount: count,
                      itemBuilder: (c, idx) {
                        final d = lapDurations[idx];
                        Color? tileColor;
                        if (idx == fastestIndex) tileColor = Colors.green[50];
                        if (idx == slowestIndex) tileColor = Colors.red[50];
                        return Container(
                          color: tileColor,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Text('Okrążenie ${idx + 1}: ${_formatDurationPrecise(d)}'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // stats tiles
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    _statTile('Najszybsze', _formatDurationPrecise(Duration(milliseconds: fastestMs))),
                    _statTile('Najwolniejsze', _formatDurationPrecise(Duration(milliseconds: slowestMs))),
                    _statTile('Średnie', _formatDurationPrecise(Duration(milliseconds: avgMs))),
                    _statTile('Odchylenie', '±${stdSec.toStringAsFixed(1)}s'),
                  ]),
                  const SizedBox(height: 12),
                  // mini bar chart for laps using fl_chart
                  SizedBox(height: 140, child: _buildBarChartLaps(lapMs, fastestIndex, slowestIndex)),
                ]);
              }),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Sessions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartHR() {
    final hr = widget.session.heartRateData ?? [];
    final down = _downsampleIntList(hr, widget.session.elapsedTime, 60);
    final spots = <FlSpot>[];
    final intervalSec = (widget.session.elapsedTime > 0 && down.isNotEmpty) ? (widget.session.elapsedTime / down.length) : 1.0;
    for (var i = 0; i < down.length; i++) {
      final minutes = (i * intervalSec) / 60.0;
      spots.add(FlSpot(minutes, down[i].toDouble()));
    }

    return LineChart(
      LineChartData(
        minY: 30,
        maxY: 200,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response == null || response.lineBarSpots == null) return;
            final spot = response.lineBarSpots!.first;
            setState(() {
              _hoverText = 'Time: ${spot.x.toStringAsFixed(2)} min, HR: ${spot.y.toStringAsFixed(0)} bpm';
            });
          },
          handleBuiltInTouches: true,
          touchTooltipData: const LineTouchTooltipData(tooltipBgColor: Colors.black54),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.red,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartPace() {
    final pace = widget.session.paceData ?? [];
    final down = _downsampleDoubleList(pace, widget.session.elapsedTime, 60);
    final spots = <FlSpot>[];
    final intervalSec = (widget.session.elapsedTime > 0 && down.isNotEmpty) ? (widget.session.elapsedTime / down.length) : 1.0;
    for (var i = 0; i < down.length; i++) {
      final minutes = (i * intervalSec) / 60.0;
      spots.add(FlSpot(minutes, down[i]));
    }

    return LineChart(
      LineChartData(
        minY: spots.map((s) => s.y).fold<double>(double.infinity, (p, e) => e < p ? e : p) - 0.5,
        maxY: spots.map((s) => s.y).fold<double>(-double.infinity, (p, e) => e > p ? e : p) + 0.5,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response == null || response.lineBarSpots == null) return;
            final spot = response.lineBarSpots!.first;
            setState(() {
              _hoverText = 'Time: ${spot.x.toStringAsFixed(2)} min, Pace: ${spot.y.toStringAsFixed(2)} min/100m';
            });
          },
          handleBuiltInTouches: true,
          touchTooltipData: const LineTouchTooltipData(tooltipBgColor: Colors.black54),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartLaps(List<int> lapMs, int fastestIndex, int slowestIndex) {
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < lapMs.length; i++) {
      final val = lapMs[i] / 1000.0; // seconds
      final color = i == fastestIndex
          ? Colors.green
          : (i == slowestIndex ? Colors.red : Colors.blue);
      groups.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: val, color: color, width: 12)],
      ));
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        // basic touch handling preserved by fl_chart defaults
      ),
    );
  }

  List<int> _downsampleIntList(List<int> values, int elapsedSec, int targetIntervalSec) {
    if (values.isEmpty) return [];
    final intervalSec = elapsedSec > 0 ? (elapsedSec / values.length) : 1.0;
    final groupSize = (targetIntervalSec / intervalSec).round().clamp(1, values.length);
    final result = <int>[];
    for (var i = 0; i < values.length; i += groupSize) {
      final group = values.sublist(i, (i + groupSize).clamp(0, values.length));
      final avg = (group.reduce((a, b) => a + b) / group.length).round();
      result.add(avg);
    }
    return result;
  }

  List<double> _downsampleDoubleList(List<double> values, int elapsedSec, int targetIntervalSec) {
    if (values.isEmpty) return [];
    final intervalSec = elapsedSec > 0 ? (elapsedSec / values.length) : 1.0;
    final groupSize = (targetIntervalSec / intervalSec).round().clamp(1, values.length);
    final result = <double>[];
    for (var i = 0; i < values.length; i += groupSize) {
      final group = values.sublist(i, (i + groupSize).clamp(0, values.length));
      final avg = group.reduce((a, b) => a + b) / group.length;
      result.add(avg);
    }
    return result;
  }

  String _formatDurationPrecise(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = (d.inMilliseconds % 1000) ~/ 10; // centiseconds
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    final cs = ms.toString().padLeft(2, '0');
    return '$mm:$ss.$cs';
  }

  Widget _statTile(String title, String value) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(title, style: const TextStyle(color: Colors.grey)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours}h ${minutes}m ${secs}s';
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
