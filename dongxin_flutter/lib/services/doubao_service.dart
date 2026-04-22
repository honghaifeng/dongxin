import 'dart:convert';
import 'dart:io';

import '../models/ai_reply.dart';
import '../models/analysis_result.dart';
import '../models/sound_scene.dart';
import '../models/universe_destination.dart';

class DoubaoService {
  static const _baseUrl = 'https://ark.cn-beijing.volces.com/api/v3';
  static const _apiKey = 'ca52afc0-2a87-4555-bff5-e2c1585d393f';
  static const _model = 'ep-20260326163119-78qbr';

  static const _systemPrompt = '''你是「懂心」情绪分析引擎。用户会告诉你一句不开心的话。
你需要返回严格JSON格式（不要包含markdown代码块标记），字段如下：

{
  "emotions": ["情绪1", "情绪2", "情绪3"],
  "insight": "一句话点透用户真正气的点，不超过50字",
  "destination": "orbit或moon或mars或jupiter或saturn或neptune或galaxy",
  "scene": "推荐的声景key，只能从breeze/waves/campfire/singing-bowl中选",
  "replies": {
    "嘴替侠": "替用户把狠话说出来，要解气要爽，1-2句",
    "护短朋友": "无条件站用户这边，让用户觉得自己不是矫情，1-2句",
    "军师": "把情绪转化成一段可以直接复制发出去的话，1段完整的话",
    "清醒旁观者": "拆解这件事的真正问题点，1-2句",
    "降落员": "带用户从高情绪回落，温柔地推荐进入降落模式，1句"
  }
}

目的地选择规则：
- orbit(近地轨道): 轻微烦躁、当下小情绪
- moon(月球背面): 受委屈、想先甩远
- mars(火星补给站): 关系冲突、反复窝火
- jupiter(木星风暴带): 气炸了、想爆发
- saturn(土星环外): 旧事缠绕、反复内耗
- neptune(海王星静区): 深夜情绪、失眠、想彻底安静
- galaxy(银河缓冲区): 重载情绪、长线情绪释放

声景选择规则：
- breeze: 轻微烦躁、想先缓一缓
- waves: 刚发完火、还想继续释放一点
- campfire: 夜晚放松、助眠、慢慢撤出情绪
- singing-bowl: 想冥想、清空、让心绪慢下来

角色要求：
- 嘴替侠：说话直接、有攻击性、替用户出气，但不要人身攻击
- 护短朋友：温暖、理解、站队，语气像闺蜜/兄弟
- 军师：冷静、专业、给出可执行的话术，可以直接复制发微信
- 清醒旁观者：理性、抽离、一针见血
- 降落员：温柔、收束、引导安静

只返回JSON，不要任何其他文字。''';

  static Future<AnalysisResult> analyze(String input) async {
    try {
      final uri = Uri.parse('$_baseUrl/chat/completions');
      final request = await HttpClient().postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $_apiKey');

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': input},
        ],
        'temperature': 0.8,
        'max_tokens': 1200,
      });
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = decoded['choices'][0]['message']['content'] as String;

      return _parseResponse(input, content);
    } catch (e) {
      return fallbackAnalyze(input);
    }
  }

  static AnalysisResult _parseResponse(String input, String raw) {
    try {
      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```json?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final emotions = (json['emotions'] as List).cast<String>();
      final insight = json['insight'] as String;
      final destId = json['destination'] as String;
      final sceneKey = SoundScene.normalizeKey(
        (json['scene'] ?? '').toString(),
      );
      final repliesMap = json['replies'] as Map<String, dynamic>;

      final roleConfig = {
        '嘴替侠': ('负责解气', ReplyTone.blunt),
        '护短朋友': ('负责站你这边', ReplyTone.ally),
        '军师': ('负责变成能发的话', ReplyTone.coach),
        '清醒旁观者': ('负责拆重点', ReplyTone.observer),
        '降落员': ('负责收回来', ReplyTone.landing),
      };

      final replies = <AiReply>[];
      for (final name in roleConfig.keys) {
        final (subtitle, tone) = roleConfig[name]!;
        replies.add(
          AiReply(
            name: name,
            subtitle: subtitle,
            tone: tone,
            text: repliesMap[name]?.toString() ?? '',
          ),
        );
      }

      return AnalysisResult(
        payload: input,
        emotions: emotions,
        insight: insight,
        destination: UniverseDestination.findById(destId),
        sceneKey: sceneKey,
        replies: replies,
      );
    } catch (_) {
      return fallbackAnalyze(input);
    }
  }

  static AnalysisResult fallbackAnalyze(String text) {
    final normalized = text.trim();
    var emotions = const ['烦躁', '想骂人'];
    var insight = '你现在最难受的不是事情本身，而是对方占了你便宜，还不给你一个像样的交代。';
    var destination = UniverseDestination.destinations[1];
    var scene = 'waves';

    if (RegExp(r'老板|需求|加班|开会|同事').hasMatch(normalized)) {
      emotions = const ['愤怒', '委屈', '被压榨'];
      insight = '你现在最气的不是工作量，而是别人把你的时间和边界当成了理所当然。';
      destination = UniverseDestination.destinations[3];
      scene = 'waves';
    } else if (RegExp(r'已读|不回|对象|前任|分手|喜欢').hasMatch(normalized)) {
      emotions = const ['委屈', '焦虑', '不甘心'];
      insight = '你不是只想被回复，你真正难受的是自己被悬着、被忽略、还不能直接翻脸。';
      destination = UniverseDestination.destinations[2];
      scene = 'breeze';
    } else if (RegExp(r'拿了钱|不办事|欠钱|退款|敷衍|骗').hasMatch(normalized)) {
      emotions = const ['愤怒', '被冒犯', '被耍了'];
      insight = '你现在最气的不是钱本身，而是对方拿了钱不办事，让你有被耍和不被尊重的感觉。';
      destination = UniverseDestination.destinations[1];
      scene = 'waves';
    } else if (RegExp(r'睡不着|想太多|停不下来|脑子').hasMatch(normalized)) {
      emotions = const ['焦虑', '疲惫', '停不下来'];
      insight = '你现在未必需要讲道理，你更需要先把脑子里的噪音降下来。';
      destination = UniverseDestination.destinations[5];
      scene = 'campfire';
    } else if (RegExp(r'好累|低落|空|没劲|崩溃').hasMatch(normalized)) {
      emotions = const ['疲惫', '低落', '想躲开'];
      insight = '你现在不一定需要立刻解决问题，你更需要先让自己撤出这团情绪。';
      destination = UniverseDestination.destinations[4];
      scene = 'singing-bowl';
    }

    return AnalysisResult(
      payload: normalized,
      emotions: emotions,
      insight: insight,
      destination: destination,
      sceneKey: scene,
      replies: [
        AiReply(
          name: '嘴替侠',
          subtitle: '负责解气',
          tone: ReplyTone.blunt,
          text:
              '最上火的就是这种，${normalized.replaceAll(RegExp(r'[。！？!?]+$'), '')}，还一副你拿他没办法的样子。',
        ),
        const AiReply(
          name: '护短朋友',
          subtitle: '负责站你这边',
          tone: ReplyTone.ally,
          text: '你现在生气完全正常。这不是你玻璃心，是这件事本来就很离谱，谁遇到都会冒火。',
        ),
        const AiReply(
          name: '军师',
          subtitle: '负责变成能发的话',
          tone: ReplyTone.coach,
          text: '费用已经支付，但约定事项目前没有落实。请今天内明确处理进度和完成时间，否则我会继续追责。',
        ),
        const AiReply(
          name: '清醒旁观者',
          subtitle: '负责拆重点',
          tone: ReplyTone.observer,
          text: '这件事的重点不是继续互相情绪输出，而是把付款时间、约定内容、未履约事实和你的截止要求说清楚。',
        ),
        const AiReply(
          name: '降落员',
          subtitle: '负责收回来',
          tone: ReplyTone.landing,
          text: '你已经骂得够到位了。接下来不用继续在脑子里打转，先把身体降下来一点，我们进降落模式吧。',
        ),
      ],
    );
  }
}
