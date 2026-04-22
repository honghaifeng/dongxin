import 'ai_reply.dart';

class LaunchRecord {
  LaunchRecord({
    required this.id,
    required this.launchedAt,
    required this.input,
    required this.emotions,
    required this.insight,
    required this.destinationId,
    required this.replies,
    required this.sceneKey,
  });

  final String id;
  final DateTime launchedAt;
  final String input;
  final List<String> emotions;
  final String insight;
  final String destinationId;
  final List<AiReply> replies;
  final String sceneKey;

  factory LaunchRecord.fromJson(Map<String, dynamic> json) {
    return LaunchRecord(
      id: json['id'] as String,
      launchedAt: DateTime.parse(json['launchedAt'] as String),
      input: json['input'] as String,
      emotions: (json['emotions'] as List).cast<String>(),
      insight: json['insight'] as String,
      destinationId: json['destinationId'] as String,
      replies: (json['replies'] as List)
          .map((r) => AiReply.fromJson(r as Map<String, dynamic>))
          .toList(),
      sceneKey: json['sceneKey'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'launchedAt': launchedAt.toIso8601String(),
        'input': input,
        'emotions': emotions,
        'insight': insight,
        'destinationId': destinationId,
        'replies': replies.map((r) => r.toJson()).toList(),
        'sceneKey': sceneKey,
      };
}
