class SoundScene {
  const SoundScene({
    required this.key,
    required this.title,
    required this.description,
    required this.badge,
    required this.duration,
    required this.destinationId,
    this.audioUrl = '',
    this.categories = const [],
  });

  final String key;
  final String title;
  final String description;
  final String badge;
  final String duration;
  final String destinationId;
  final String audioUrl;
  final List<String> categories;

  static const _cdn = 'http://qiniu.pianai.love/dongxin/audio';

  static const allCategories = ['全部', '舒缓', '释放', '助眠', '冥想'];

  static const all = <SoundScene>[
    SoundScene(
      key: 'breeze',
      title: '微风轻拂',
      description: '适合刚有点烦、还没到爆发的时候。',
      badge: '舒缓',
      duration: '5 分钟',
      destinationId: 'orbit',
      audioUrl: '$_cdn/breeze.ogg',
      categories: ['舒缓'],
    ),
    SoundScene(
      key: 'waves',
      title: '海浪拍岸',
      description: '适合刚发完火、脑子还在打转的时候。',
      badge: '推荐',
      duration: '5 分钟',
      destinationId: 'moon',
      audioUrl: '$_cdn/waves.ogg',
      categories: ['释放'],
    ),
    SoundScene(
      key: 'campfire',
      title: '篝火噼啪',
      description: '适合下班以后彻底撤出今天的情绪。',
      badge: '助眠',
      duration: '10 分钟',
      destinationId: 'saturn',
      audioUrl: '$_cdn/campfire.ogg',
      categories: ['助眠'],
    ),
    SoundScene(
      key: 'singing-bowl',
      title: '钟声冥想',
      description: '适合重载情绪、需要缓慢清空的时候。',
      badge: '冥想',
      duration: '10 分钟',
      destinationId: 'galaxy',
      audioUrl: '$_cdn/singing-bowl.ogg',
      categories: ['冥想'],
    ),
  ];

  static List<SoundScene> forDestination(String destinationId) {
    return all.where((s) => s.destinationId == destinationId).toList();
  }

  static List<SoundScene> forCategory(String category) {
    if (category == '全部') return all;
    return all.where((s) => s.categories.contains(category)).toList();
  }

  static String normalizeKey(String key) {
    switch (key) {
      case 'breeze':
      case 'waves':
      case 'campfire':
      case 'singing-bowl':
        return key;
      case 'birds':
      case 'stream':
      case 'bamboo':
        return 'breeze';
      case 'thunder':
      case 'heavy-rain':
        return 'waves';
      case 'rain':
      case 'crickets':
      case 'white-noise':
      case 'deep-sea':
        return 'campfire';
      case 'cosmic-hum':
        return 'singing-bowl';
      default:
        return 'waves';
    }
  }

  static SoundScene findByKey(String key) {
    final normalized = normalizeKey(key);
    return all.firstWhere((s) => s.key == normalized, orElse: () => all[1]);
  }
}
