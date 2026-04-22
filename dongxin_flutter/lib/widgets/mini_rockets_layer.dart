import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/history_service.dart';

class MiniRocketsLayer extends StatefulWidget {
  const MiniRocketsLayer({super.key});

  @override
  State<MiniRocketsLayer> createState() => _MiniRocketsLayerState();
}

class _MiniRocketsLayerState extends State<MiniRocketsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _rng = math.Random();
  final List<_FlyingRocket> _rockets = [];
  List<String> _historyTexts = [];

  static const _maxRockets = 12;
  static const _spawnIntervalMs = 1400;
  int _lastSpawnMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ticker.addListener(_tick);
    _loadHistory();
    _seedInitialRockets();
  }

  void _seedInitialRockets() {
    for (var i = 0; i < 5; i++) {
      _rockets.add(_FlyingRocket(
        x: 0.08 + _rng.nextDouble() * 0.84,
        y: _rng.nextDouble() * 1.0,
        speed: 0.0012 + _rng.nextDouble() * 0.0018,
        scale: 0.4 + _rng.nextDouble() * 0.6,
        opacity: 0.12 + _rng.nextDouble() * 0.28,
        text: null,
      ));
    }
  }

  Future<void> _loadHistory() async {
    final records = await HistoryService.load();
    if (!mounted) return;
    setState(() {
      _historyTexts = records.map((r) => r.input).toList();
    });
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_rockets.length < _maxRockets &&
        now - _lastSpawnMs > _spawnIntervalMs) {
      _lastSpawnMs = now;
      _spawnRocket();
    }

    setState(() {
      for (final r in _rockets) {
        r.y -= r.speed;
      }
      _rockets.removeWhere((r) => r.y < -0.15);
    });
  }

  void _spawnRocket() {
    final hasText = _historyTexts.isNotEmpty && _rng.nextDouble() < 0.45;
    String? text;
    if (hasText) {
      text = _historyTexts[_rng.nextInt(_historyTexts.length)];
      if (text.length > 14) text = '${text.substring(0, 13)}...';
    }

    _rockets.add(_FlyingRocket(
      x: 0.06 + _rng.nextDouble() * 0.88,
      y: 1.02 + _rng.nextDouble() * 0.08,
      speed: 0.0010 + _rng.nextDouble() * 0.0020,
      scale: 0.4 + _rng.nextDouble() * 0.7,
      opacity: 0.12 + _rng.nextDouble() * 0.30,
      text: text,
    ));
  }

  @override
  void dispose() {
    _ticker.removeListener(_tick);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: _rockets.map((r) {
              final left = r.x * w;
              final top = r.y * h;
              return Positioned(
                left: left - 20 * r.scale,
                top: top,
                child: Opacity(
                  opacity: r.opacity,
                  child: Transform.scale(
                    scale: r.scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (r.text != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            constraints: const BoxConstraints(maxWidth: 120),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              r.text!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        SvgPicture.asset(
                          'assets/rocket-mini.svg',
                          width: 36,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _FlyingRocket {
  _FlyingRocket({
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.opacity,
    this.text,
  });

  final double x;
  double y;
  final double speed;
  final double scale;
  final double opacity;
  final String? text;
}
