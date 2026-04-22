import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/calm_content.dart';
import '../models/sound_scene.dart';
import '../utils/constants.dart';
import 'video_player_page.dart';

class SoundPage extends StatefulWidget {
  const SoundPage({super.key, this.initialTab = CalmContentTab.audio});

  final CalmContentTab initialTab;

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  final AudioPlayer _player = AudioPlayer();
  String _activeAudioKey = '';
  bool _isAudioPlaying = false;
  String _activeCategory = '全部';
  int? _timerMinutes;
  Timer? _timer;
  int _remainingSeconds = 0;
  late CalmContentTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(SoundScene scene) async {
    _timer?.cancel();
    setState(() {
      _activeAudioKey = scene.key;
      _isAudioPlaying = true;
      _timerMinutes = null;
      _remainingSeconds = 0;
    });
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.loop);
    if (scene.audioUrl.isNotEmpty) {
      await _player.play(UrlSource(scene.audioUrl));
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _player.stop();
    setState(() {
      _activeAudioKey = '';
      _isAudioPlaying = false;
      _timerMinutes = null;
      _remainingSeconds = 0;
    });
  }

  Future<void> _togglePlaybackBar() async {
    if (_activeAudioKey.isEmpty) return;
    if (_isAudioPlaying) {
      await _player.pause();
      if (!mounted) return;
      setState(() => _isAudioPlaying = false);
      return;
    }
    await _player.resume();
    if (!mounted) return;
    setState(() => _isAudioPlaying = true);
  }

  Future<void> _toggle(SoundScene scene) async {
    if (_activeAudioKey == scene.key) {
      await _togglePlaybackBar();
    } else {
      await _play(scene);
    }
  }

  void _setTimer(int minutes) {
    _timer?.cancel();
    setState(() {
      _timerMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds <= 1) {
        t.cancel();
        _stop();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String _formatTimer() {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openVisualContent(CalmContent content) async {
    await _player.stop();
    final contents = content.type == CalmContentType.mv
        ? CalmContent.mv
        : CalmContent.videos;
    final initialIndex = contents.indexWhere((item) => item.id == content.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          contents: contents,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenes = SoundScene.forCategory(_activeCategory);
    final showPlayerBar = _activeAudioKey.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF07111F),
                foregroundColor: Colors.white,
                pinned: true,
                title: const Text(
                  '静心空间',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '降下来一点，不止可以听，也可以看。',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '你可以选声音，也可以看 MV 和视频，让情绪慢慢从身体里退下去。',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.58),
                          height: 1.6,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ContentTabBar(
                        activeTab: _activeTab,
                        onChanged: (tab) => setState(() => _activeTab = tab),
                      ),
                      const SizedBox(height: 14),
                      if (_activeTab == CalmContentTab.audio)
                        _CategoryTabs(
                          active: _activeCategory,
                          onTap: (c) => setState(() => _activeCategory = c),
                        ),
                    ],
                  ),
                ),
              ),
              if (_activeTab == CalmContentTab.audio)
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 14,
                    bottom: showPlayerBar ? 120 : 24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final scene = scenes[index];
                      final active = _activeAudioKey == scene.key;
                      return _SoundCard(
                        scene: scene,
                        active: active,
                        playing: active && _isAudioPlaying,
                        onTap: () => _toggle(scene),
                      );
                    }, childCount: scenes.length),
                  ),
                ),
              if (_activeTab == CalmContentTab.mv)
                _VisualSectionList(
                  title: '今晚先让画面陪你一下',
                  items: CalmContent.mv,
                  bottomPadding: showPlayerBar ? 120 : 24,
                  onTap: _openVisualContent,
                ),
              if (_activeTab == CalmContentTab.video)
                _VisualSectionList(
                  title: '如果你想被温柔带一下',
                  items: CalmContent.videos,
                  bottomPadding: showPlayerBar ? 120 : 24,
                  onTap: _openVisualContent,
                ),
            ],
          ),
          if (showPlayerBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PlayerBar(
                scene: SoundScene.findByKey(_activeAudioKey),
                playing: _isAudioPlaying,
                timerMinutes: _timerMinutes,
                timerDisplay: _remainingSeconds > 0 ? _formatTimer() : null,
                onTogglePlayback: _togglePlaybackBar,
                onSetTimer: _setTimer,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentTabBar extends StatelessWidget {
  const _ContentTabBar({required this.activeTab, required this.onChanged});

  final CalmContentTab activeTab;
  final ValueChanged<CalmContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (CalmContentTab.audio, '声音', Icons.graphic_eq_rounded),
      (CalmContentTab.mv, 'MV', Icons.music_video_rounded),
      (CalmContentTab.video, '视频', Icons.ondemand_video_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: tabs.map((item) {
          final (tab, label, icon) = item;
          final active = tab == activeTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF18345C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: active
                          ? DxColors.blueText
                          : Colors.white.withValues(alpha: 0.48),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: active
                            ? DxColors.blueText
                            : Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.active, required this.onTap});

  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: SoundScene.allCategories.map((cat) {
          final isActive = cat == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onTap(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isActive
                      ? const Color(0xFF1E3A5F)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: isActive
                        ? DxColors.blueText.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isActive ? DxColors.blueText : DxColors.subtitleText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _VisualSectionList extends StatelessWidget {
  const _VisualSectionList({
    required this.title,
    required this.items,
    required this.bottomPadding,
    required this.onTap,
  });

  final String title;
  final List<CalmContent> items;
  final double bottomPadding;
  final ValueChanged<CalmContent> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate.fixed([
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VisualContentCard(
                content: item,
                onTap: () => onTap(item),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _VisualContentCard extends StatelessWidget {
  const _VisualContentCard({required this.content, required this.onTap});

  final CalmContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VisualCover(content: content),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: DxColors.blueText.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          content.badge,
                          style: const TextStyle(
                            color: DxColors.blueText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        content.duration,
                        style: const TextStyle(
                          color: DxColors.subtitleText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: content.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: DxColors.subtitleText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    content.available ? '打开看看' : '入口先留好，资源补上就能播',
                    style: TextStyle(
                      color: content.available
                          ? DxColors.green
                          : Colors.white.withValues(alpha: 0.46),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualCover extends StatelessWidget {
  const _VisualCover({required this.content});

  final CalmContent content;

  @override
  Widget build(BuildContext context) {
    final baseColor = content.type == CalmContentType.mv
        ? const Color(0xFF162848)
        : const Color(0xFF132A2B);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 116,
        height: 162,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor,
                    baseColor.withValues(alpha: 0.72),
                    const Color(0xFF091426),
                  ],
                ),
              ),
            ),
            if (content.previewUrl.isNotEmpty)
              Image.network(
                content.previewUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox.shrink();
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.42),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  content.typeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  content.type == CalmContentType.mv
                      ? Icons.music_video_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white.withValues(alpha: 0.92),
                  size: 22,
                ),
              ),
            ),
            if (!content.available)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black.withValues(alpha: 0.26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '资源待补',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.scene,
    required this.active,
    required this.playing,
    required this.onTap,
  });

  final SoundScene scene;
  final bool active;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: active
              ? const Color(0xFF0D1F2E)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: active
                ? DxColors.green.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? DxColors.green.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    scene.badge,
                    style: TextStyle(
                      color: active ? DxColors.green : const Color(0xFF9EB6D6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (active)
                  Icon(
                    playing
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_circle_outline_rounded,
                    color: DxColors.green,
                    size: 20,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              scene.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              scene.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? Colors.white.withValues(alpha: 0.6)
                    : const Color(0xFF96A8C7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  active && playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: active ? DxColors.green : DxColors.blueText,
                  size: 32,
                ),
                const Spacer(),
                Text(
                  scene.duration,
                  style: const TextStyle(
                    color: Color(0xFF94A6C5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.scene,
    required this.playing,
    required this.timerMinutes,
    required this.timerDisplay,
    required this.onTogglePlayback,
    required this.onSetTimer,
  });

  final SoundScene scene;
  final bool playing;
  final int? timerMinutes;
  final String? timerDisplay;
  final VoidCallback onTogglePlayback;
  final ValueChanged<int> onSetTimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF00A1528),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: DxColors.green.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: DxColors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (timerDisplay != null)
                      Text(
                        '剩余 $timerDisplay',
                        style: const TextStyle(
                          color: DxColors.green,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onTogglePlayback,
                icon: Icon(
                  playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                ),
                color: Colors.white70,
                iconSize: 36,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '定时',
                style: TextStyle(color: DxColors.subtitleText, fontSize: 13),
              ),
              const SizedBox(width: 12),
              ...[5, 10, 30].map(
                (m) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TimerChip(
                    label: '$m分钟',
                    active: timerMinutes == m,
                    onTap: () => onSetTimer(m),
                  ),
                ),
              ),
              _TimerChip(
                label: '持续',
                active: timerMinutes == null,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? DxColors.green.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: active
                ? DxColors.green.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? DxColors.green : DxColors.subtitleText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
