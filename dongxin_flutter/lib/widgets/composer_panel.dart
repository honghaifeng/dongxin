import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ComposerPanel extends StatelessWidget {
  const ComposerPanel({
    super.key,
    required this.textController,
    required this.currentInput,
    required this.isListening,
    required this.speechReady,
    required this.speechStatus,
    required this.onMicPressStart,
    required this.onMicPressEnd,
    required this.onLaunch,
  });

  final TextEditingController textController;
  final String currentInput;
  final bool isListening;
  final bool speechReady;
  final String speechStatus;
  final VoidCallback onMicPressStart;
  final VoidCallback onMicPressEnd;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final hasInput = currentInput.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xC2070F1D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 38,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 输入框 + 发射按钮
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: textController,
                    readOnly: isListening,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: isListening ? '正在听你说...' : '把这口气说出来...',
                      hintStyle: TextStyle(
                        color: isListening
                            ? DxColors.red.withValues(alpha: 0.7)
                            : DxColors.dimText,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _LaunchButton(enabled: hasInput && !isListening, onTap: onLaunch),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            speechStatus,
            style: TextStyle(
              fontSize: 13,
              color: speechReady
                  ? (isListening ? DxColors.red : DxColors.blueText)
                  : DxColors.orange,
            ),
          ),
          const SizedBox(height: 14),
          // 大圆形语音按钮
          RecordButton(
            listening: isListening,
            ready: speechReady,
            onPressStart: onMicPressStart,
            onPressEnd: onMicPressEnd,
          ),
        ],
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? DxColors.launchButton
              : DxColors.launchButtonDisabled.withValues(alpha: 0.4),
        ),
        child: Icon(
          Icons.rocket_launch_rounded,
          size: 24,
          color: enabled ? const Color(0xFF101828) : Colors.white24,
        ),
      ),
    );
  }
}

class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.listening,
    required this.ready,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final bool listening;
  final bool ready;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.listening) _controller.repeat();
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !old.listening) {
      _controller.repeat();
    } else if (!widget.listening && old.listening) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => widget.onPressStart(),
      onTapUp: (_) => widget.onPressEnd(),
      onTapCancel: widget.onPressEnd,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final scale = 0.85 + (_controller.value * 0.4);
                  final opacity = (1 - _controller.value).clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DxColors.red.withValues(alpha: opacity * 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.listening
                      ? const [Color(0xFFFF8D72), Color(0xFFFF5F7A)]
                      : const [Color(0xFF74BBFF), Color(0xFF3E7FFF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (widget.listening
                                ? const Color(0xFFFF5F7A)
                                : const Color(0xFF3E7FFF))
                            .withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
