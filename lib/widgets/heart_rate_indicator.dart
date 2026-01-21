import 'package:flutter/material.dart';
import '../models/heart_rate_zones.dart';

HeartRateZone getZoneForHr(int hr, int age) {
  final maxHr = (220 - age);
  final zones = StandardHeartRateZones.createZones(maxHeartRate: maxHr);
  return zones.firstWhere(
    (z) => hr >= z.minBpm && hr <= z.maxBpm,
    orElse: () => zones.last,
  );
}

class HeartRateIndicator extends StatelessWidget {
  final int heartRate;
  final int age;

  const HeartRateIndicator({super.key, required this.heartRate, this.age = 30});

  @override
  Widget build(BuildContext context) {
    final zone = getZoneForHr(heartRate, age);
    final maxHr = 220 - age;
    final percentMax = ((heartRate / maxHr) * 100).round();
    
    // Determine zone name for clarity
    String getZoneName(HeartRateZone zone) {
      if (zone.name.contains('Recovery')) return 'Recovery';
      if (zone.name.contains('Aerobic')) return 'Aerobic';
      if (zone.name.contains('Threshold')) return 'Threshold';
      if (zone.name.contains('VO2')) return 'VO2 Max';
      return zone.name;
    }

    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: zone.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: zone.color, width: 3),
        boxShadow: [
          BoxShadow(
            color: zone.color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Icon(Icons.favorite, color: zone.color, size: 28),
          const SizedBox(height: 4),
          // HR Value
          Text(
            '$heartRate',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: zone.color,
              letterSpacing: -2,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          // Zone Label (not "% MAX" but actual zone name)
          Text(
            getZoneName(zone),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          // Intensity Percentage Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: zone.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$percentMax%',
              style: TextStyle(
                fontSize: 10,
                color: zone.color,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
