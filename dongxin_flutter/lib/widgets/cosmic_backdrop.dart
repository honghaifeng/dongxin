import 'package:flutter/material.dart';

class CosmicBackdrop extends StatelessWidget {
  const CosmicBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08111E), Color(0xFF08182F)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.85, -1.0),
                  radius: 1.15,
                  colors: [
                    const Color(0xFF62AFFF).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.92, -0.88),
                  radius: 0.9,
                  colors: [
                    const Color(0xFFFFD87B).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 180,
            left: 42,
            child: _Planet(color: Color(0xFFF2F4FA), size: 14),
          ),
          const Positioned(
            top: 94,
            right: 68,
            child: _Planet(color: Color(0xFF7CB6FF), size: 34),
          ),
          const Positioned(top: 242, right: 48, child: _RingPlanet()),
          const Positioned(
            top: 338,
            left: 34,
            child: _Planet(color: Color(0xFF6AD7B5), size: 18),
          ),
        ],
      ),
    );
  }
}

class _Planet extends StatelessWidget {
  const _Planet({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.7), color],
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16)],
      ),
    );
  }
}

class _RingPlanet extends StatelessWidget {
  const _RingPlanet();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.2,
            child: Container(
              width: 78,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFB7D0FF), width: 2),
              ),
            ),
          ),
          const _Planet(color: Color(0xFF9F7BFF), size: 34),
        ],
      ),
    );
  }
}
