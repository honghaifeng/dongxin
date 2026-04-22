import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/calm_content.dart';
import '../utils/constants.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.contents,
    this.initialIndex = 0,
  });

  final List<CalmContent> contents;
  final int initialIndex;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  late int _currentIndex;
  int _loadSeq = 0;
  bool _loading = true;
  bool _failed = false;
  bool _cardExpanded = true;
  bool _switching = false;

  CalmContent get _content => widget.contents[_currentIndex];

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  void _toggleCard() {
    setState(() {
      _cardExpanded = !_cardExpanded;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.contents.length - 1);
    _setup();
  }

  Future<void> _setup() async {
    final loadSeq = ++_loadSeq;
    final content = _content;
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    if (!content.available) {
      if (!mounted || loadSeq != _loadSeq) return;
      setState(() {
        _loading = false;
        _failed = true;
        _switching = false;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(content.url));

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || loadSeq != _loadSeq) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
        _switching = false;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted || loadSeq != _loadSeq) return;
      setState(() {
        _failed = true;
        _loading = false;
        _switching = false;
      });
    }
  }

  Future<void> _switchContent(int delta) async {
    if (widget.contents.length <= 1 || _switching || _loading) return;
    final nextIndex = _currentIndex + delta;
    if (nextIndex < 0 || nextIndex >= widget.contents.length) return;
    setState(() {
      _switching = true;
      _currentIndex = nextIndex;
      _cardExpanded = true;
    });
    await _setup();
  }

  Future<void> _handleVerticalDragEnd(DragEndDetails details) async {
    if (_switching || _loading) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 500) return;
    if (velocity < 0) {
      await _switchContent(1);
    } else {
      await _switchContent(-1);
    }
  }

  @override
  void dispose() {
    _loadSeq++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final playButtonBottom =
        MediaQuery.of(context).padding.bottom + (_cardExpanded ? 214.0 : 128.0);
    return Scaffold(
      backgroundColor: const Color(0xFF050B16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: DxColors.blueText),
                )
              : _failed
              ? _UnavailableState(content: content)
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlayback,
                  onVerticalDragEnd: _handleVerticalDragEnd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.22),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                            stops: const [0, 0.4, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _TopCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            right: 16,
            bottom: playButtonBottom,
            child: _PlayPauseButton(
              playing: _controller?.value.isPlaying ?? false,
              onTap: _togglePlayback,
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleCard,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        _cardExpanded ? 12 : 10,
                        16,
                        _cardExpanded ? 14 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x54101A29),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 34,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DxColors.blueText.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    content.badge,
                                    style: TextStyle(
                                      color: DxColors.blueText.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  content.duration,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.38),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _cardExpanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white.withValues(alpha: 0.42),
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              content.title,
                              maxLines: _cardExpanded ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _cardExpanded ? 22 : 20,
                                fontWeight: FontWeight.w900,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              content.subtitle,
                              maxLines: _cardExpanded ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            if (_cardExpanded) ...[
                              const SizedBox(height: 8),
                              Text(
                                content.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  height: 1.58,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.contents.length > 1)
            Positioned(
              right: 14,
              top: MediaQuery.of(context).padding.top + 62,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.contents.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({required this.content});

  final CalmContent content;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              content.type == CalmContentType.mv
                  ? Icons.music_video_rounded
                  : Icons.ondemand_video_rounded,
              color: Colors.white.withValues(alpha: 0.65),
              size: 54,
            ),
            const SizedBox(height: 14),
            const Text(
              '资源还没补进来',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '这个${content.typeLabel}入口已经接好了，等你把七牛云链接补上就能直接播放。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xCC0B1628),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}
