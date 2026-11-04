import 'dart:convert';

import '../lib/config.dart';
import '../lib/models/web_search_hit.dart';
import '../lib/services/web_search.dart';
import '../lib/services/web_search_service.dart';

int _failures = 0;

void check(String name, bool condition) {
  if (condition) {
    print('PASS: $name');
  } else {
    _failures++;
    print('FAIL: $name');
  }
}

void section(String title) => print('\n=== $title ===');

/// 假的搜索客户端：不打网络，只回放一段给定的响应。
class _FakeClient implements WebSearchClient {
  _FakeClient(this.response, {this.error});

  final String response;
  final Object? error;
  int calls = 0;
  String? lastQuery;
  String? lastKey;

  @override
  Future<String> search({
    required String query,
    required String apiKey,
    required String searchUrl,
    required int count,
  }) async {
    calls++;
    lastQuery = query;
    lastKey = apiKey;
    if (error != null) throw error!;
    return response;
  }
}

String _payload(List<Map<String, dynamic>> results) =>
    jsonEncode({'results': results});

Future<void> main() async {
  // ---------------------------------------------------------------- 查询
  section('查询构造');
  final fakeForQuery = _FakeClient(_payload([]));
  final q = WebSearchService(fakeForQuery);

  check('短消息不搜（"嗯"）', !q.shouldSearch('嗯'));
  check('短消息不搜（"继续说"）', !q.shouldSearch('继续说'));
  check('正常问题要搜',
      q.shouldSearch('最近有什么值得玩的新游戏吗'));
  check('换行被压成空格', q.buildQuery('第一行\n第二行') == '第一行 第二行');
  check('超过 128 字被截断',
      q.buildQuery('长' * 300).length == WebSearchService.maxQueryLength);

  // ---------------------------------------------------------------- 解析
  section('响应解析');
  final parsed = q.parseResults(_payload([
    {
      'title': '某篇报道',
      'url': 'https://example.com/a',
      'snippet': '短摘要不该被用到',
      'summary': '长摘要，给模型读的那一版',
      'date': '2026-11-01T00:00:00Z',
    },
    {
      'title': '',
      'url': '',
      'snippet': '没有 summary 时退回 snippet',
    },
    {
      'title': '空正文',
      'url': 'https://example.com/c',
      'snippet': '',
      'summary': '',
    },
  ]));
  check('只保留有正文的结果（3 → 2）', parsed.length == 2);
  check('优先用 summary', parsed.first.summary == '长摘要，给模型读的那一版');
  check('日期被保留', parsed.first.date == '2026-11-01T00:00:00Z');
  check('没有 summary 时退回 snippet',
      parsed[1].summary == '没有 summary 时退回 snippet');
  check('空标题有兜底', parsed[1].title == '（无标题）');
  check('不是 JSON → 空列表', q.parseResults('<html>').isEmpty);
  check('没有 results 字段 → 空列表', q.parseResults('{"x":1}').isEmpty);
  check('results 不是数组 → 空列表', q.parseResults('{"results":{}}').isEmpty);
  check('最多只取 $kMaxSearchResults',
      q.parseResults(_payload([
            for (var i = 0; i < 10; i++)
              {'title': 't$i', 'url': '', 'summary': 's$i'},
          ])).length ==
          kMaxSearchResults);

  // ---------------------------------------------------------------- 组装
  section('上下文组装');
  final block = q.formatForContext(parsed);
  check('写明这是网上查到的资料', block.contains('从网上刚查到的资料'));
  check('写明不许编造资料里没有的内容', block.contains('不要编造资料里没有的内容'));
  check('写明无关就不要硬拐话题', block.contains('就当没看见'));
  check('带上标题与摘要',
      block.contains('某篇报道') && block.contains('长摘要，给模型读的那一版'));
  check('空结果返回空串', q.formatForContext(const <WebSearchHit>[]).isEmpty);

  // ---------------------------------------------------------------- 端到端（假客户端）
  section('buildContext（含失败降级）');
  final okClient = _FakeClient(_payload([
    {'title': '标题', 'url': 'https://example.com', 'summary': '摘要'},
  ]));
  final okService = WebSearchService(okClient);
  final ctx = await okService.buildContext(
    query: '最近出了什么新游戏',
    apiKey: 'sk-test',
    searchUrl: kDefaultSearchUrl,
  );
  check('查到就返回资料块', ctx != null && ctx.contains('标题'));
  check('查询被送进客户端', okClient.lastQuery == '最近出了什么新游戏');
  check('apiKey 被送进客户端', okClient.lastKey == 'sk-test');

  final failing = WebSearchService(_FakeClient('', error: Exception('boom')));
  check('搜索失败返回 null，不抛异常',
      await failing.buildContext(
            query: '最近出了什么新游戏',
            apiKey: 'sk-test',
            searchUrl: kDefaultSearchUrl,
          ) ==
          null);

  final empty = WebSearchService(_FakeClient(_payload([])));
  check('零结果返回 null',
      await empty.buildContext(
            query: '最近出了什么新游戏',
            apiKey: 'sk-test',
            searchUrl: kDefaultSearchUrl,
          ) ==
          null);

  final notCalled = _FakeClient(_payload([]));
  final shortService = WebSearchService(notCalled);
  check('太短的消息根本不发请求',
      await shortService.buildContext(
            query: '嗯',
            apiKey: 'sk-test',
            searchUrl: kDefaultSearchUrl,
          ) ==
          null &&
          notCalled.calls == 0);

  final noKey = _FakeClient(_payload([]));
  check('没有 API Key 不发请求',
      await WebSearchService(noKey).buildContext(
            query: '最近出了什么新游戏',
            apiKey: '',
            searchUrl: kDefaultSearchUrl,
          ) ==
          null &&
          noKey.calls == 0);

  print('');
  if (_failures == 0) {
    print('全部通过。');
  } else {
    print('$_failures 项失败。');
  }
}
