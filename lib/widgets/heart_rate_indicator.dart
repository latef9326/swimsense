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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: zone.color.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: zone.color, width: 2.5),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, color: zone.color, size: 26),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$heartRate',
                style: TextStyle(fontSize: 24, color: zone.color, fontWeight: FontWeight.bold),
              ),
            ),
            Text('bpm', style: TextStyle(color: zone.color.withOpacity(0.85), fontSize: 11)),
            const SizedBox(height: 2),
            Flexible(
              child: Text(zone.name, style: TextStyle(color: zone.color, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
