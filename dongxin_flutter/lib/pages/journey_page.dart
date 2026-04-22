import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/analysis_result.dart';
import '../models/calm_content.dart';
import '../models/launch_record.dart';
import '../models/sound_scene.dart';
import '../models/universe_destination.dart';
import '../services/doubao_service.dart';
import '../services/history_service.dart';
import '../widgets/result_sheet.dart';
import 'sound_page.dart';

class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key, required this.input});

  final String input;

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

enum _Phase { routeInfo, flying, arrived }

class _JourneyPageState extends State<JourneyPage>
    with TickerProviderStateMixin {
  late AnimationController _journeyController;
  late final AnimationController _arrivalGlowController;
  late final AnimationController _dropController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  DraggableScrollableController? _sheetController;

  AnalysisResult _result = AnalysisResult.initial();
  _Phase _phase = _Phase.routeInfo;
  bool _showSheet = false;
  String _activeScene = '';
  double _routeInfoOpacity = 1.0;
  double _buttonOpacity = 1.0;

  int _targetIndex = 1;
  UniverseDestination _targetDest = UniverseDestination.destinations[1];
  bool _aiDone = false;
  List<String> _destHistory = [];
  late String _recordId;

  @override
  void initState() {
    super.initState();
    _result = AnalysisResult.loading(widget.input);

    _journeyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _arrivalGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _recordId = DateTime.now().millisecondsSinceEpoch.toString();

    _startRoute();
  }

  Future<void> _startRoute() async {
    final analysisFuture = DoubaoService.analyze(widget.input);

    // Phase 1: 展示航线信息 2 秒
    setState(() {
      _phase = _Phase.routeInfo;
      _routeInfoOpacity = 1.0;
    });

    final result = await analysisFuture;
    if (!mounted) return;

    final destIndex = UniverseDestination.indexById(result.destination.id);
    setState(() {
      _result = result;
      _targetIndex = destIndex;
      _targetDest = result.destination;
      _activeScene = '';
      _aiDone = true;
    });

    await _saveRecord(result);
    await _loadDestHistory(result.destination.id);

    // 航线信息至少展示 2 秒
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Phase 2: 渐隐航线信息
    setState(() => _routeInfoOpacity = 0.0);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Phase 3: 开始飞行
    _flyTo(_targetIndex);
  }

  void _flyTo(int destIndex) {
    final duration = Duration(milliseconds: 2500 + destIndex * 400);
    _journeyController.stop();
    _journeyController.duration = duration;
    _journeyController.reset();

    setState(() {
      _phase = _Phase.flying;
      _showSheet = false;
      _buttonOpacity = 1.0;
      _targetIndex = destIndex;
      _targetDest = UniverseDestination.destinations[destIndex];
    });

    _sheetController?.dispose();
    _sheetController = DraggableScrollableController();
    _sheetController!.addListener(_onSheetChanged);

    _journeyController.forward();

    _journeyController.addStatusListener(_onJourneyDone);
  }

  void _onJourneyDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _journeyController.removeStatusListener(_onJourneyDone);

    setState(() => _phase = _Phase.arrived);
    _arrivalGlowController.repeat(reverse: true);
    _dropController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _showSheet = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || _sheetController == null) return;
        _sheetController!.animateTo(
          0.80,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  void _onSheetChanged() {
    if (_sheetController == null || !_sheetController!.isAttached) return;
    final size = _sheetController!.size;
    final newOpacity = size > 0.3 ? 0.0 : 1.0;
    if (_buttonOpacity != newOpacity) {
      setState(() => _buttonOpacity = newOpacity);
    }
  }

  Future<void> _continueFlight() async {
    if (_targetIndex >= UniverseDestination.destinations.length - 1) return;

    _audioPlayer.stop();
    _arrivalGlowController.stop();
    _arrivalGlowController.reset();

    final nextIndex = _targetIndex + 1;
    final nextDest = UniverseDestination.destinations[nextIndex];
    setState(() {
      _destHistory = [];
      _activeScene = '';
      _result = AnalysisResult(
        payload: _result.payload,
        emotions: _result.emotions,
        insight: _result.insight,
        destination: nextDest,
        sceneKey: _result.sceneKey,
        replies: _result.replies,
      );
    });
    await _saveCurrentRecord(nextDest.id);
    await _loadDestHistory(nextDest.id);
    _flyTo(nextIndex);
  }

  Future<void> _loadDestHistory(String destId) async {
    final records = await HistoryService.load();
    if (!mounted) return;
    final texts = records
        .where((r) => r.id == _recordId && r.destinationId == destId)
        .map((r) => r.input)
        .toList();
    setState(() => _destHistory = texts);
  }

  Future<void> _saveRecord(AnalysisResult result) async {
    await HistoryService.save(
      LaunchRecord(
        id: _recordId,
        launchedAt: DateTime.now(),
        input: widget.input,
        emotions: result.emotions,
        insight: result.insight,
        destinationId: result.destination.id,
        replies: result.replies,
        sceneKey: result.sceneKey,
      ),
    );
  }

  Future<void> _saveCurrentRecord(String destinationId) async {
    await HistoryService.save(
      LaunchRecord(
        id: _recordId,
        launchedAt: DateTime.now(),
        input: widget.input,
        emotions: _result.emotions,
        insight: _result.insight,
        destinationId: destinationId,
        replies: _result.replies,
        sceneKey: _result.sceneKey,
      ),
    );
  }

  Future<void> _playScene(String scene) async {
    setState(() => _activeScene = scene);
    await _audioPlayer.stop();
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    final sceneData = SoundScene.findByKey(scene);
    if (sceneData.audioUrl.isNotEmpty) {
      await _audioPlayer.play(UrlSource(sceneData.audioUrl));
    }
  }

  Future<void> _toggleScene(String scene) async {
    if (_activeScene == scene) {
      await _audioPlayer.stop();
      setState(() => _activeScene = '');
      return;
    }
    await _playScene(scene);
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  void _openSoundPage([CalmContentTab initialTab = CalmContentTab.audio]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoundPage(initialTab: initialTab)),
    );
  }

  void _goHome() {
    _audioPlayer.stop();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _journeyController.dispose();
    _arrivalGlowController.dispose();
    _dropController.dispose();
    _sheetController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final canContinue =
        _phase == _Phase.arrived &&
        _targetIndex < UniverseDestination.destinations.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // 星空背景 + 目的地航点
          if (_phase != _Phase.routeInfo)
            AnimatedBuilder(
              animation: _journeyController,
              builder: (context, _) => CustomPaint(
                painter: _JourneyPainter(
                  progress: _journeyController.value,
                  targetIndex: _targetIndex,
                  arrived: _phase == _Phase.arrived,
                  glowValue: _phase == _Phase.arrived
                      ? _arrivalGlowController.value
                      : 0,
                ),
                size: Size.infinite,
              ),
            ),

          // 航线信息页 (发射前展示)
          if (_phase == _Phase.routeInfo)
            _RouteInfoOverlay(
              opacity: _routeInfoOpacity,
              destination: _targetDest,
              input: widget.input,
              aiDone: _aiDone,
            ),

          // 到达时的发光
          if (_phase == _Phase.arrived)
            AnimatedBuilder(
              animation: _arrivalGlowController,
              builder: (context, _) => Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.1),
                        radius: 0.6,
                        colors: [
                          _targetDest.color.withValues(
                            alpha: 0.08 + _arrivalGlowController.value * 0.06,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 到达后显示该目的地当前停留的内容
          if (_phase == _Phase.arrived && _destHistory.isNotEmpty)
            Positioned(
              left: 20,
              width: size.width * 0.42,
              top: size.height * 0.45 + 32,
              child: IgnorePointer(
                ignoring: _buttonOpacity == 0,
                child: AnimatedBuilder(
                  animation: _dropController,
                  builder: (context, _) {
                    final raw = _dropController.value.clamp(0.0, 1.0);
                    final t = Curves.easeOutCubic.transform(raw);
                    return Transform.translate(
                      offset: Offset((1 - t) * 84, (1 - t) * -96),
                      child: Transform.scale(
                        scale: 0.82 + (0.18 * t),
                        alignment: Alignment.topLeft,
                        child: Opacity(
                          opacity: _buttonOpacity * t,
                          child: _DestHistoryList(
                            texts: _destHistory,
                            currentInput: widget.input,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 火箭 (飞行 + 到达)
          if (_phase != _Phase.routeInfo)
            AnimatedBuilder(
              animation: Listenable.merge([
                _journeyController,
                _dropController,
              ]),
              builder: (context, _) {
                final p = _journeyController.value;
                final rocketY = p < 0.15 ? 0.7 - (p / 0.15) * 0.25 : 0.45;
                final dropT = _phase == _Phase.arrived
                    ? Curves.easeOutCubic.transform(_dropController.value)
                    : 0.0;
                final bubbleOffsetY = _phase == _Phase.arrived
                    ? (dropT * 76)
                    : 0.0;
                final bubbleOpacity = _phase == _Phase.arrived
                    ? (1 - dropT).clamp(0.0, 1.0)
                    : 1.0;
                return Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * rocketY - 110,
                  child: Column(
                    children: [
                      if (_phase == _Phase.arrived)
                        _ArrivalBadge(destination: _targetDest),
                      Transform.translate(
                        offset: Offset(0, bubbleOffsetY),
                        child: Opacity(
                          opacity: bubbleOpacity,
                          child: _PayloadBubble(text: widget.input),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/rocket-main.svg',
                        width: 120,
                        height: 170,
                      ),
                      if (_phase == _Phase.flying) _RocketFlame(intensity: p),
                    ],
                  ),
                );
              },
            ),

          // 到达后的操作按钮 (继续发射 + 回首页)
          if (_phase == _Phase.arrived)
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.12,
              child: IgnorePointer(
                ignoring: _buttonOpacity == 0,
                child: AnimatedOpacity(
                  opacity: _buttonOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      if (canContinue)
                        FilledButton.icon(
                          onPressed: _continueFlight,
                          icon: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 20,
                          ),
                          label: const Text('继续发射，飞更远'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: _goHome,
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: const Text('回到首页'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 顶部状态栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goHome,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white54,
                  ),
                  const Spacer(),
                  if (_phase == _Phase.flying)
                    Text(
                      '飞行中...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_phase == _Phase.arrived)
                    Text(
                      '已到达 ${_targetDest.name}',
                      style: TextStyle(
                        color: _targetDest.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 结果面板 (DraggableScrollableSheet)
          if (_showSheet && _sheetController != null)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.08,
              minChildSize: 0.08,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.08, 0.80],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xF2071020),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(34),
                    ),
                  ),
                  child: ResultSheetContent(
                    scrollController: scrollController,
                    result: _result,
                    activeScene: _activeScene,
                    onCopy: _copyText,
                    onSceneTap: _toggleScene,
                    onGoHome: _goHome,
                    onOpenContentPage: _openSoundPage,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// --- 航线信息页 ---

class _RouteInfoOverlay extends StatelessWidget {
  const _RouteInfoOverlay({
    required this.opacity,
    required this.destination,
    required this.input,
    required this.aiDone,
  });

  final double opacity;
  final UniverseDestination destination;
  final String input;
  final bool aiDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 500),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF040A14), Color(0xFF0C1A30)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '宇宙航线已锁定',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: destination.color.withValues(alpha: 0.2),
                    border: Border.all(
                      color: destination.color.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: destination.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  destination.name,
                  style: TextStyle(
                    color: destination.color,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '预计到达 ${destination.eta}',
                  style: const TextStyle(
                    color: Color(0xFFFFE09F),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    destination.summary,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (!aiDone)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: destination.color.withValues(alpha: 0.5),
                    ),
                  ),
                if (aiDone)
                  Text(
                    '即将发射...',
                    style: TextStyle(
                      color: destination.color.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 旅程画布 ---

class _JourneyPainter extends CustomPainter {
  _JourneyPainter({
    required this.progress,
    required this.targetIndex,
    required this.arrived,
    required this.glowValue,
  });

  final double progress;
  final int targetIndex;
  final bool arrived;
  final double glowValue;

  static final List<_Star> _stars = _generateStars(220);

  static List<_Star> _generateStars(int count) {
    final rng = math.Random(77);
    return List.generate(
      count,
      (_) => _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        brightness: 0.2 + rng.nextDouble() * 0.8,
        size: 0.5 + rng.nextDouble() * 1.8,
        speed: 0.6 + rng.nextDouble() * 0.8,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawStars(canvas, size);
    _drawWaypoints(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        const Color(0xFF040A14),
        const Color(0xFF08182F),
      ]);
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  void _drawStars(Canvas canvas, Size size) {
    final speed = _currentSpeed();
    final trailLength = speed * 60;

    for (final star in _stars) {
      final scrollOffset = progress * star.speed * 8;
      final y =
          ((star.y + scrollOffset) % 1.3) * size.height - size.height * 0.15;
      final x = star.x * size.width;

      if (trailLength < 2) {
        final paint = Paint()
          ..color = Colors.white.withValues(alpha: star.brightness * 0.6);
        canvas.drawCircle(Offset(x, y), star.size, paint);
      } else {
        final endY = y;
        final startY = y - trailLength;
        final paint = Paint()
          ..shader = ui.Gradient.linear(Offset(x, startY), Offset(x, endY), [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(
              alpha: star.brightness * (0.3 + speed * 0.5),
            ),
          ])
          ..strokeWidth = star.size * (0.8 + speed * 0.5)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
      }
    }
  }

  double _currentSpeed() {
    if (arrived) return 0;
    final curve = Curves.easeInOutCubic;
    const dt = 0.02;
    final t1 = curve.transform(progress.clamp(0, 1));
    final t2 = curve.transform((progress - dt).clamp(0, 1));
    return ((t1 - t2) / dt).clamp(0, 3);
  }

  void _drawWaypoints(Canvas canvas, Size size) {
    final dests = UniverseDestination.destinations;
    final targetAlt = dests[targetIndex].altitude;
    final currentAlt = Curves.easeInOutCubic.transform(progress) * targetAlt;

    for (var i = 0; i <= targetIndex; i++) {
      final dest = dests[i];
      final relativePos = (dest.altitude - currentAlt) / targetAlt;
      final screenY = size.height * 0.45 + relativePos * size.height * 2.5;

      if (screenY < -80 || screenY > size.height + 80) continue;

      final passed = currentAlt >= dest.altitude;
      final isTarget = i == targetIndex;
      final alpha = (isTarget && arrived) ? 1.0 : (passed ? 0.3 : 0.7);

      final linePaint = Paint()
        ..color = dest.color.withValues(alpha: alpha * 0.3)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        linePaint,
      );

      final planetSize = (isTarget && arrived) ? 18.0 : 10.0;
      final planetPaint = Paint()..color = dest.color.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(size.width * 0.15, screenY),
        planetSize,
        planetPaint,
      );

      if (isTarget && arrived) {
        final glowPaint = Paint()
          ..color = dest.color.withValues(alpha: glowValue * 0.2);
        canvas.drawCircle(
          Offset(size.width * 0.15, screenY),
          planetSize + 12,
          glowPaint,
        );
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: passed && !isTarget ? '${dest.name} ✓' : dest.name,
          style: TextStyle(
            color: dest.color.withValues(alpha: alpha),
            fontSize: (isTarget && arrived) ? 20 : 14,
            fontWeight: (isTarget && arrived)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          size.width * 0.15 + planetSize + 12,
          screenY - textPainter.height / 2,
        ),
      );

      if (!passed || (isTarget && arrived)) {
        final etaPainter = TextPainter(
          text: TextSpan(
            text: dest.eta,
            style: TextStyle(
              color: Colors.white.withValues(alpha: alpha * 0.5),
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        etaPainter.paint(
          canvas,
          Offset(
            size.width * 0.85 - etaPainter.width,
            screenY - etaPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_JourneyPainter old) =>
      old.progress != progress ||
      old.arrived != arrived ||
      old.glowValue != glowValue ||
      old.targetIndex != targetIndex;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.brightness,
    required this.size,
    required this.speed,
  });

  final double x;
  final double y;
  final double brightness;
  final double size;
  final double speed;
}

// --- 到达徽章 ---

class _ArrivalBadge extends StatelessWidget {
  const _ArrivalBadge({required this.destination});

  final UniverseDestination destination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: destination.color.withValues(alpha: 0.15),
              border: Border.all(
                color: destination.color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '已到达 · ${destination.name}',
              style: TextStyle(
                color: destination.color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '你的不开心已被送达',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 火箭顶部载荷气泡 ---

class _PayloadBubble extends StatelessWidget {
  const _PayloadBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final display = text.length > 20 ? '${text.substring(0, 19)}...' : text;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A44),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// --- 目的地历史列表 ---

class _DestHistoryList extends StatelessWidget {
  const _DestHistoryList({required this.texts, required this.currentInput});

  final List<String> texts;
  final String currentInput;

  @override
  Widget build(BuildContext context) {
    final text = texts.isNotEmpty ? texts.first : currentInput;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFD87B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A44),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFD87B).withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- 火箭尾焰 ---

class _RocketFlame extends StatelessWidget {
  const _RocketFlame({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    final height = 30 + intensity * 50;
    return Container(
      width: 24,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFAA44).withValues(alpha: 0.8),
            const Color(0xFFFF6633).withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
