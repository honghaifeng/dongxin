import 'package:flutter/material.dart';

class UniverseDestination {
  const UniverseDestination({
    required this.id,
    required this.name,
    required this.description,
    required this.eta,
    required this.note,
    required this.summary,
    required this.color,
    required this.altitude,
  });

  final String id;
  final String name;
  final String description;
  final String eta;
  final String note;
  final String summary;
  final Color color;
  final double altitude;

  static const destinations = <UniverseDestination>[
    UniverseDestination(
      id: 'orbit',
      name: '近地轨道',
      description: '轻微烦躁 / 当下小情绪，先让它离开你一圈。',
      eta: '18分钟',
      note: '提醒文案：你的不开心已脱离桌面，正在低轨环绕。',
      summary: '这枚火箭进入了近地轨道，它会先绕着你转一圈，再慢慢离开。',
      color: Color(0xFF7CB6FF),
      altitude: 0.12,
    ),
    UniverseDestination(
      id: 'moon',
      name: '月球背面',
      description: '受了委屈 / 想先甩远，先送去看不见的地方。',
      eta: '2小时18分',
      note: '提醒文案：你的不开心已经飞离你 384,400 公里。',
      summary: '这枚火箭已锁定月球背面，情绪载荷正在脱离地球引力。',
      color: Color(0xFFF2F4FA),
      altitude: 0.26,
    ),
    UniverseDestination(
      id: 'mars',
      name: '火星补给站',
      description: '关系冲突 / 反复窝火，适合做一次中途卸载。',
      eta: '7小时42分',
      note: '提醒文案：你的烦心事正在火星补给站排队卸载。',
      summary: '这枚火箭正在飞往火星补给站，让反复回放的情绪先离你更远一些。',
      color: Color(0xFFFF8D72),
      altitude: 0.42,
    ),
    UniverseDestination(
      id: 'jupiter',
      name: '木星风暴带',
      description: '气炸了 / 想爆发，就送去更狂的地方。',
      eta: '19小时',
      note: '提醒文案：你的怒气已进入木星风暴带，不会再堵在胸口。',
      summary: '这枚火箭正在穿越木星风暴带，适合承接那种想当场掀桌的火。',
      color: Color(0xFFFFD87B),
      altitude: 0.58,
    ),
    UniverseDestination(
      id: 'saturn',
      name: '土星环外',
      description: '旧事缠绕 / 反复内耗，绕远一点才会慢慢松开。',
      eta: '1天14小时',
      note: '提醒文案：那件缠着你的事，已经开始绕出土星环了。',
      summary: '这枚火箭已绕出土星环，适合把那些总回来的旧情绪一层层剥开。',
      color: Color(0xFF9F7BFF),
      altitude: 0.72,
    ),
    UniverseDestination(
      id: 'neptune',
      name: '海王星静区',
      description: '深夜情绪 / 想彻底安静，去宇宙最冷的地方降温。',
      eta: '2天7小时',
      note: '提醒文案：你的不开心正在海王星静区进入静音模式。',
      summary: '这枚火箭驶向海王星静区，适合夜里那种说不清但停不下来的情绪。',
      color: Color(0xFF6AD7B5),
      altitude: 0.86,
    ),
    UniverseDestination(
      id: 'galaxy',
      name: '银河缓冲区',
      description: '重载情绪 / 长线航行，是更远的会员航线。',
      eta: '5天12小时',
      note: '提醒文案：你的情绪载荷已进入银河缓冲区，正在做深空稀释。',
      summary: '这枚火箭正在飞离太阳系，去更远的缓冲区做长线稀释。',
      color: Color(0xFFB8CFFF),
      altitude: 1.0,
    ),
  ];

  static UniverseDestination findById(String id) {
    return destinations.firstWhere(
      (d) => d.id == id,
      orElse: () => destinations[1],
    );
  }

  static int indexById(String id) {
    return destinations.indexWhere((d) => d.id == id).clamp(0, destinations.length - 1);
  }
}
