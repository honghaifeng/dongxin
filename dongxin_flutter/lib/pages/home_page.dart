import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/prompt_item.dart';
import '../services/dialog_service.dart';
import '../widgets/composer_panel.dart';
import '../widgets/cosmic_backdrop.dart';
import '../widgets/mini_rockets_layer.dart';
import 'history_page.dart';
import 'journey_page.dart';
import 'sound_page.dart';

class DongxinHomePage extends StatefulWidget {
  const DongxinHomePage({super.key});

  @override
  State<DongxinHomePage> createState() => _DongxinHomePageState();
}

class _DongxinHomePageState extends State<DongxinHomePage> {
  static const List<PromptItem> _prompts = [
    PromptItem('先别忍，把这口气发射出去', '说一句，懂心帮你接住。'),
    PromptItem('你只管说，我帮你消气', '不用解释很多，先把这句放出来。'),
    PromptItem('把心里这句话，发射出去', '今天这口气，先别憋在心里。'),
    PromptItem('先说出来，剩下的交给懂心', '你负责发射，我们负责接住。'),
    PromptItem('今天这口气，发出去再说', '先爽一下，再慢慢收回来。'),
    PromptItem('别憋着，先发射', '你的委屈，需要一个出口。'),
    PromptItem('把委屈装进火箭里', '让它先离开你一会儿。'),
    PromptItem('懂你这口气，先发射出去', '你现在最需要的，不是被教育，是先被理解。'),
    PromptItem('懂心一下，先把不开心送走', '发射完，再让自己降落下来。'),
  ];

  final TextEditingController _textController = TextEditingController();

  StreamSubscription<DialogEvent>? _dialogSub;

  bool _speechReady = false;
  bool _speechInitializing = false;
  bool _isListening = false;
  bool _micPermissionGranted = false;
  bool _requestingMicPermission = false;
  bool _engineStarting = false;
  bool _pendingStop = false;
  String _speechStatus = '正在初始化语音...';
  Timer? _stopDelayTimer;

  String _dialogAppId = '3766462587';
  String _dialogAppKey = '';
  String _dialogToken = 'LhKkIhpUnsWv0go_3M3nbb15OJrBXHub';
  String _dialogResourceId = 'volc.speech.dialog';

  String _input = '';
  PromptItem _prompt = _prompts.first;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() => _input = _textController.text.trim());
    });
    _shufflePrompt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_bootstrapVoice());
    });
  }

  @override
  void dispose() {
    _dialogSub?.cancel();
    _stopDelayTimer?.cancel();
    DialogService.destroy();
    DialogService.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _shufflePrompt() {
    _prompt = _prompts[math.Random().nextInt(_prompts.length)];
  }

  Future<void> _bootstrapVoice() async {
    await _ensureMicPermission();
    if (_micPermissionGranted) {
      await _initDialogSpeech();
    }
  }

  Future<void> _initDialogSpeech() async {
    if (_speechInitializing || _speechReady) return;
    _speechInitializing = true;
    try {
      final uri = Uri.parse('https://www.pianai.love/api/voice/dialog_config');
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['code'] == 0 && decoded['data'] is Map) {
          final data = decoded['data'] as Map;
          _dialogAppId = (data['app_id'] ?? _dialogAppId).toString();
          _dialogAppKey = (data['app_key'] ?? _dialogAppKey).toString();
          _dialogToken = (data['token'] ?? _dialogToken).toString();
          _dialogResourceId = (data['resource_id'] ?? _dialogResourceId)
              .toString();
        }
      }
    } catch (_) {}

    final ok = await DialogService.init(
      appId: _dialogAppId,
      appKey: _dialogAppKey,
      token: _dialogToken,
      resourceId: _dialogResourceId,
      uid: 'dongxin_user',
    );

    _dialogSub = DialogService.events.listen(_handleDialogEvent);

    if (!mounted) return;
    setState(() {
      _speechReady = ok;
      _speechStatus = ok ? '按住开始说，松开结束' : '语音引擎初始化失败';
    });
    _speechInitializing = false;
  }

  void _handleDialogEvent(DialogEvent event) {
    if (!mounted) return;
    switch (event.event) {
      case 'engine_start':
        setState(() {
          _engineStarting = false;
          _isListening = true;
          _speechStatus = '正在听你说...';
        });
        if (_pendingStop) {
          _scheduleStop();
        }
        break;
      case 'asr_start':
        setState(() {
          _engineStarting = false;
          _textController.text = '';
          _speechStatus = '正在听你说...';
        });
        if (_pendingStop) {
          _scheduleStop();
        }
        break;
      case 'asr_result':
        final text = _extractAsrText(event.data);
        if (text.isNotEmpty) {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
          setState(() {
            _speechStatus = '识别中：$text';
          });
        }
        break;
      case 'asr_end':
        setState(() {
          _pendingStop = false;
          _engineStarting = false;
          _isListening = false;
          _speechStatus = _input.trim().isEmpty ? '没听清，再试一次' : '载荷已装填，可以发射了';
        });
        break;
      case 'engine_stop':
        setState(() {
          _pendingStop = false;
          _engineStarting = false;
          _isListening = false;
          _speechStatus = _input.trim().isEmpty ? '已停止录音' : '载荷已装填，可以发射了';
        });
        break;
      case 'error':
        setState(() {
          _pendingStop = false;
          _engineStarting = false;
          _isListening = false;
          _speechStatus = '语音识别失败，请重试';
        });
        break;
    }
  }

  Future<void> _ensureMicPermission() async {
    if (_requestingMicPermission) return;
    _requestingMicPermission = true;
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      _micPermissionGranted = status.isGranted;
      if (_micPermissionGranted) {
        await _initDialogSpeech();
        if (mounted && !_speechReady) {
          setState(() {
            _speechStatus = '正在初始化语音...';
          });
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能语音输入')));
      setState(() {
        _speechStatus = status.isPermanentlyDenied
            ? '麦克风权限被永久拒绝，请到系统设置开启'
            : '请先允许麦克风权限';
      });
    } finally {
      _requestingMicPermission = false;
    }
  }

  String _extractAsrText(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final results = decoded['results'];
        if (results is List && results.isNotEmpty) {
          final first = results.first;
          if (first is Map &&
              (first['text'] ?? '').toString().trim().isNotEmpty) {
            return first['text'].toString().trim();
          }
        }
        final text = (decoded['text'] ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {
      return raw.trim();
    }
    return '';
  }

  Future<void> _toggleMic() async {
    if (!_micPermissionGranted) {
      await _ensureMicPermission();
    }
    if (!_micPermissionGranted) return;

    if (!_speechReady) {
      await _initDialogSpeech();
    }

    if (_isListening) {
      await DialogService.stop();
      if (!mounted) return;
      setState(() {
        _pendingStop = false;
        _engineStarting = false;
        _isListening = false;
        _speechStatus = _input.trim().isEmpty ? '已停止录音' : '载荷已装填，可以发射了';
      });
      return;
    }

    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DialogService.lastError ?? '语音引擎未就绪')),
        );
        setState(() {
          _speechStatus = DialogService.lastError ?? '语音引擎未就绪';
        });
      }
      return;
    }

    setState(() {
      _pendingStop = false;
      _engineStarting = true;
      _textController.text = '';
      _speechStatus = '正在启动语音识别...';
    });

    final started = await DialogService.start(
      botName: '懂心',
      systemRole: '你只做中文语音识别，把用户原话如实转成文字，不做任何回复。',
      speakingStyle: '',
      speaker: '',
    );
    if (!mounted) return;
    if (!started) {
      setState(() {
        _pendingStop = false;
        _engineStarting = false;
        _isListening = false;
        _speechStatus = DialogService.lastError ?? '启动识别失败';
      });
    }
  }

  Future<void> _startMicPress() async {
    if (_isListening || _engineStarting) return;
    if (!_micPermissionGranted) {
      await _ensureMicPermission();
    }
    if (!_micPermissionGranted) return;
    if (!_speechReady) {
      await _initDialogSpeech();
    }
    await _toggleMic();
  }

  Future<void> _endMicPress() async {
    if (!_isListening && !_engineStarting) return;
    _pendingStop = true;
    if (mounted) {
      setState(() {
        _speechStatus = '正在整理你刚刚说的话...';
      });
    }
    if (_isListening) {
      _scheduleStop();
    }
  }

  void _scheduleStop() {
    _stopDelayTimer?.cancel();
    _stopDelayTimer = Timer(const Duration(milliseconds: 900), () async {
      await DialogService.stop();
    });
  }

  Future<void> _launch() async {
    final input = _input.trim();
    if (input.isEmpty) return;

    if (_isListening) {
      await DialogService.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    }

    FocusScope.of(context).unfocus();

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) => JourneyPage(input: input),
        transitionsBuilder: (context, anim, a2, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (!mounted) return;
    setState(() {
      _input = '';
      _textController.clear();
      _shufflePrompt();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const CosmicBackdrop(),
          const MiniRocketsLayer(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1C3059), Color(0xFF20385F)],
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFF5F86BE,
                            ).withValues(alpha: 0.38),
                          ),
                        ),
                        child: const Text(
                          '懂心 · 消灭不开心',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8CC1FF),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SoundPage()),
                        ),
                        icon: const Icon(Icons.spa_rounded),
                        color: Colors.white54,
                        tooltip: '静心空间',
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryPage(),
                          ),
                        ),
                        icon: const Icon(Icons.history_rounded),
                        color: Colors.white54,
                        tooltip: '发射记录',
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  Text(
                    '懂你这口气',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF74B7FF).withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _prompt.headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.06,
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _prompt.subline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.65,
                      color: Color(0xFFA3B3CD),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => setState(_shufflePrompt),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('换一句'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ComposerPanel(
                  textController: _textController,
                  currentInput: _input,
                  isListening: _isListening,
                  speechReady: _speechReady,
                  speechStatus: _speechStatus,
                  onMicPressStart: _startMicPress,
                  onMicPressEnd: _endMicPress,
                  onLaunch: _launch,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
