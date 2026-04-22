import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../models/ai_reply.dart';
import '../models/calm_content.dart';
import '../models/sound_scene.dart';
import '../utils/constants.dart';

class ResultSheetContent extends StatelessWidget {
  const ResultSheetContent({
    super.key,
    required this.scrollController,
    required this.result,
    required this.activeScene,
    required this.onCopy,
    required this.onSceneTap,
    required this.onGoHome,
    required this.onOpenContentPage,
  });

  final ScrollController scrollController;
  final AnalysisResult result;
  final String activeScene;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onSceneTap;
  final VoidCallback onGoHome;
  final ValueChanged<CalmContentTab> onOpenContentPage;

  @override
  Widget build(BuildContext context) {
    final recommendedScene = SoundScene.findByKey(result.sceneKey);
    final recommendedMv = CalmContent.recommendedMv(result.destination.id);
    final recommendedVideo = CalmContent.recommendedVideo(
      result.destination.id,
    );
    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 62,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '下拉可收起',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // 1. 情绪分析区
          _SectionCard(
            child: result.isLoading
                ? const _LoadingSkeleton()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader(
                        eyebrow: '我懂你这口气',
                        title: '先把这口气看清，再让别人替你说出来',
                      ),
                      const SizedBox(height: 14),
                      _PayloadCard(payload: result.payload),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: result.emotions
                            .map((e) => _EmotionChip(label: e))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        result.insight,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.72,
                          color: DxColors.bodyText,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 2. AI 吐槽团（紧跟情绪分析）
          if (!result.isLoading && result.replies.isNotEmpty) ...[
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(eyebrow: 'AI 吐槽团', title: '站你这边的人来了'),
                  const SizedBox(height: 14),
                  ...result.replies.map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReplyCard(reply: reply),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (result.replies.length >= 3)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => onCopy(result.replies[2].text),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Text('复制军师版'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. 降落模式（简化：推荐1个声景 + 更多链接）
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(eyebrow: '降落模式', title: '骂完了，先别想了，降下来一点'),
                const SizedBox(height: 8),
                Text(
                  '根据你现在的状态，推荐最适合的安静方式。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                _RecommendedSceneCard(
                  scene: recommendedScene,
                  active: activeScene == recommendedScene.key,
                  onTap: () => onSceneTap(recommendedScene.key),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RecommendedVisualCard(
                        content: recommendedMv,
                        onTap: () => onOpenContentPage(CalmContentTab.mv),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RecommendedVisualCard(
                        content: recommendedVideo,
                        onTap: () => onOpenContentPage(CalmContentTab.video),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: () => onOpenContentPage(CalmContentTab.audio),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '探索静心空间',
                          style: TextStyle(
                            color: DxColors.blueText.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: DxColors.blueText.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
                if (result.replies.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    result.replies.last.text,
                    style: const TextStyle(
                      color: Color(0xFFD8FFF3),
                      height: 1.7,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. 回到首页
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGoHome,
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('回到首页 · 再发射一次'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(eyebrow: '我懂你这口气', title: '正在帮你把这口气看清楚...'),
        const SizedBox(height: 20),
        ...List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: DxColors.blueText.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: DxColors.blueText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            DxColors.gold.withValues(alpha: 0.08),
            DxColors.blueText.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: DxColors.gold.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '你刚刚发射的是',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: DxColors.blueText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            payload,
            style: const TextStyle(
              color: DxColors.goldText,
              fontSize: 16,
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionChip extends StatelessWidget {
  const _EmotionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFE09F),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.reply});

  final AiReply reply;

  @override
  Widget build(BuildContext context) {
    Color accent;
    switch (reply.tone) {
      case ReplyTone.blunt:
        accent = DxColors.red;
      case ReplyTone.ally:
        accent = DxColors.gold;
      case ReplyTone.coach:
        accent = DxColors.blueText;
      case ReplyTone.observer:
        accent = const Color(0xFFB8CFFF);
      case ReplyTone.landing:
        accent = DxColors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: DxColors.card,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reply.name,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                reply.subtitle,
                style: const TextStyle(color: Color(0xFF94A6C5), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reply.text,
            style: const TextStyle(
              color: Color(0xFFEFF6FF),
              height: 1.72,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedSceneCard extends StatelessWidget {
  const _RecommendedSceneCard({
    required this.scene,
    required this.active,
    required this.onTap,
  });

  final SoundScene scene;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: DxColors.card,
        border: Border.all(
          color: active
              ? DxColors.green.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
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
                        color: DxColors.blueText.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '推荐',
                        style: TextStyle(
                          color: Color(0xFF9EB6D6),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      scene.duration,
                      style: const TextStyle(
                        color: Color(0xFF94A6C5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scene.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  scene.description,
                  style: const TextStyle(
                    color: Color(0xFF96A8C7),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? DxColors.green.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: active
                      ? DxColors.green.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(
                active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28,
                color: active ? DxColors.green : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedVisualCard extends StatelessWidget {
  const _RecommendedVisualCard({required this.content, required this.onTap});

  final CalmContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = content.type == CalmContentType.mv
        ? DxColors.gold
        : DxColors.green;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: DxColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    content.typeLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  content.type == CalmContentType.mv
                      ? Icons.music_video_rounded
                      : Icons.ondemand_video_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content.available ? '去看一会儿' : '入口先留好',
              style: TextStyle(
                color: content.available
                    ? accent
                    : Colors.white.withValues(alpha: 0.48),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
