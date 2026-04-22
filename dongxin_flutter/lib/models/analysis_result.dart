import 'ai_reply.dart';
import 'universe_destination.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.payload,
    required this.emotions,
    required this.insight,
    required this.destination,
    required this.sceneKey,
    required this.replies,
  });

  final String payload;
  final List<String> emotions;
  final String insight;
  final UniverseDestination destination;
  final String sceneKey;
  final List<AiReply> replies;

  factory AnalysisResult.initial() {
    return AnalysisResult(
      payload: '',
      emotions: const [],
      insight: '',
      destination: UniverseDestination.destinations[1],
      sceneKey: 'waves',
      replies: const [],
    );
  }

  factory AnalysisResult.loading(String payload) {
    return AnalysisResult(
      payload: payload,
      emotions: const ['分析中...'],
      insight: '正在帮你把这口气看清楚...',
      destination: UniverseDestination.destinations[1],
      sceneKey: 'waves',
      replies: const [],
    );
  }

  bool get isLoading => replies.isEmpty && emotions.isNotEmpty && emotions.first == '分析中...';
}
