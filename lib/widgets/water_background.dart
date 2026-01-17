import 'dart:math';
import 'package:flutter/material.dart';

class WaterBackground extends StatefulWidget {
  final Widget child;
  const WaterBackground({super.key, required this.child});

  @override
  State<WaterBackground> createState() => _WaterBackgroundState();
}

class _WaterBackgroundState extends State<WaterBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _waveOffset(double phase, double width) {
    // produce a horizontal offset to animate gentle waves
    return sin(phase * 2 * pi) * (width * 0.02);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
            ),
          ),
        ),
        // animated shapes
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final phase = _ctrl.value;
            return Stack(
              children: [
                // faint large circle moving horizontally
                Positioned(
                  left: size.width * 0.1 + _waveOffset(phase, size.width),
                  top: size.height * 0.05,
                  child: Opacity(
                    opacity: 0.08,
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.6,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [Color(0xFFb2ebf2), Color(0x00b2ebf2)]),
                        borderRadius: BorderRadius.circular(200),
                      ),
                    ),
                  ),
                ),
                // second wave
                Positioned(
                  right: size.width * 0.05 + _waveOffset(phase + 0.3, size.width),
                  bottom: size.height * 0.05,
                  child: Opacity(
                    opacity: 0.06,
                    child: Container(
                      width: size.width * 0.9,
                      height: size.width * 0.5,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [Color(0xFF80deea), Color(0x0080deea)]),
                        borderRadius: BorderRadius.circular(200),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // subtle overlay with noise-color
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.02)],
            ),
          ),
        ),
        // child content
        widget.child,
      ],
    );
  }
}
