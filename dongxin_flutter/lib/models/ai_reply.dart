enum ReplyTone { blunt, ally, coach, observer, landing }

class AiReply {
  const AiReply({
    required this.name,
    required this.subtitle,
    required this.tone,
    required this.text,
  });

  final String name;
  final String subtitle;
  final ReplyTone tone;
  final String text;

  factory AiReply.fromJson(Map<String, dynamic> json) {
    final toneMap = {
      'blunt': ReplyTone.blunt,
      'ally': ReplyTone.ally,
      'coach': ReplyTone.coach,
      'observer': ReplyTone.observer,
      'landing': ReplyTone.landing,
    };
    return AiReply(
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      tone: toneMap[json['tone']] ?? ReplyTone.blunt,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'tone': tone.name,
        'text': text,
      };
}
