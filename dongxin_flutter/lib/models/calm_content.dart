enum CalmContentTab { audio, mv, video }

enum CalmContentType { mv, video }

class CalmContent {
  const CalmContent({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.duration,
    required this.badge,
    required this.tags,
    required this.destinationIds,
    this.url = '',
    this.coverUrl = '',
  });

  final String id;
  final CalmContentType type;
  final String title;
  final String subtitle;
  final String description;
  final String duration;
  final String badge;
  final List<String> tags;
  final List<String> destinationIds;
  final String url;
  final String coverUrl;

  bool get available => url.trim().isNotEmpty;

  String get previewUrl {
    if (coverUrl.trim().isNotEmpty) return coverUrl.trim();
    if (!available) return '';
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}vframe/jpg/offset/1/w/720/h/1280';
  }

  String get typeLabel => switch (type) {
    CalmContentType.mv => 'MV',
    CalmContentType.video => '视频',
  };

  static const mv = <CalmContent>[
    CalmContent(
      id: 'mv-orbit-night',
      type: CalmContentType.mv,
      title: '你是我放下的那个女人',
      subtitle: '创作者“小卒”',
      description: '更适合关系里的委屈、拉扯和舍不得，像陪你把那口气慢慢放下。',
      duration: '约 3 分钟',
      badge: '陪伴 MV',
      tags: ['陪伴', '释放后', '夜晚'],
      destinationIds: ['moon', 'mars', 'jupiter'],
      url:
          'http://qiniu.pianai.love/dongxin/mv/%E4%BD%A0%E6%98%AF%E6%88%91%E6%94%BE%E4%B8%8B%E7%9A%84%E9%82%A3%E4%B8%AA%E5%A5%B3%E4%BA%BA_%E5%88%9B%E4%BD%9C%E8%80%85%E2%80%9C%E5%B0%8F%E5%8D%92%E2%80%9D.mp4',
    ),
    CalmContent(
      id: 'mv-soft-landing',
      type: CalmContentType.mv,
      title: '这就是男人',
      subtitle: '创作者“小卒”',
      description: '更适合刚发完火、心里还堵着，先借画面把那股劲释放掉一点。',
      duration: '约 4 分钟',
      badge: '沉浸 MV',
      tags: ['放空', '回落', '慢慢来'],
      destinationIds: ['saturn', 'neptune', 'galaxy'],
      url:
          'http://qiniu.pianai.love/dongxin/mv/%E8%BF%99%E5%B0%B1%E6%98%AF%E7%94%B7%E4%BA%BA_%E5%88%9B%E4%BD%9C%E8%80%85%E2%80%9C%E5%B0%8F%E5%8D%92%E2%80%9D.mp4',
    ),
  ];

  static const videos = <CalmContent>[
    CalmContent(
      id: 'video-quick-reset',
      type: CalmContentType.video,
      title: '海浪',
      subtitle: '让情绪先被海面接一下。',
      description: '更适合刚发完火、还想继续释放一点的时候，先别讲道理，先让节奏慢下来。',
      duration: '氛围短片',
      badge: '释放',
      tags: ['海浪', '回落', '释放后'],
      destinationIds: ['moon', 'jupiter', 'mars'],
      url:
          'http://qiniu.pianai.love/dongxin/movie/1776748248258-4441e4a1-task-2110001e-bfba-4683-a3ee-640c0502546e.mp4',
    ),
    CalmContent(
      id: 'video-sleep-landing',
      type: CalmContentType.video,
      title: '篝火',
      subtitle: '适合夜里把今天慢慢收住。',
      description: '更偏夜晚陪伴，像坐在火边把白天的情绪一点点撤出去。',
      duration: '氛围短片',
      badge: '夜晚',
      tags: ['篝火', '助眠', '陪伴'],
      destinationIds: ['neptune', 'saturn'],
      url:
          'http://qiniu.pianai.love/dongxin/movie/1776747663037-8e7e3a49-task-de7cc5af-c4af-4d9d-a60d-8c66849f22dc.mp4',
    ),
    CalmContent(
      id: 'video-clear-space',
      type: CalmContentType.video,
      title: '河水',
      subtitle: '适合想放空，或者让心绪流过去一点。',
      description: '更像一段轻流动感的视频，不催你振作，只是陪你把堵住的东西慢慢带走。',
      duration: '氛围短片',
      badge: '放空',
      tags: ['河水', '流动', '清理'],
      destinationIds: ['galaxy', 'saturn', 'neptune', 'orbit'],
      url:
          'http://qiniu.pianai.love/dongxin/movie/1776749016343-ec3f21d3-task-0f75fb53-184c-4dc6-b587-130968619c9f.mp4',
    ),
  ];

  static CalmContent recommendedMv(String destinationId) {
    return mv.firstWhere(
      (item) => item.destinationIds.contains(destinationId),
      orElse: () => mv.first,
    );
  }

  static CalmContent recommendedVideo(String destinationId) {
    return videos.firstWhere(
      (item) => item.destinationIds.contains(destinationId),
      orElse: () => videos.first,
    );
  }
}
