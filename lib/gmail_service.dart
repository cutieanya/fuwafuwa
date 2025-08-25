import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GmailService {
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  static const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  Future<String?> _token() async {
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  // --- 1件のメッセージから From/Date/snippet を抽出 ---
  Future<Map<String, dynamic>> _getMessageSummary(String messageId) async {
    final t = await _token();
    if (t == null) return {};

    final uri = Uri.parse(
      '$_base/messages/$messageId'
      '?format=metadata'
      '&metadataHeaders=From'
      '&metadataHeaders=Date',
    );
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode != 200) {
      throw Exception('getMessage failed: ${res.statusCode} ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;

    // internalDate はエポックms
    final internalMs = int.tryParse('${data['internalDate'] ?? ''}');
    final date = internalMs != null
        ? DateTime.fromMillisecondsSinceEpoch(internalMs, isUtc: true).toLocal()
        : null;

    // ヘッダをMap化
    String? from;
    final headers = (data['payload']?['headers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    for (final h in headers) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final value = (h['value'] ?? '').toString();
      if (name == 'from') from = value;
    }

    // From をシンプルに抽出
String fromName = '(unknown)';
if (from != null && from.isNotEmpty) {
  final emailMatch = RegExp(r'^(.*)<(.+)>$').firstMatch(from);
  if (emailMatch != null) {
    fromName = emailMatch.group(1)?.trim() ?? emailMatch.group(2)!;
  } else {
    fromName = from!;
  }
  // 余計なダブルクオートを削除
  fromName = fromName.replaceAll('"', '');
}

    // 時間は簡単に "yyyy/MM/dd HH:mm" 形式
    String timeStr = '';
    if (date != null) {
      timeStr =
          '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return {
      'id': data['id'],
      'threadId': data['threadId'],
      'from': fromName,
      'snippet': data['snippet'] ?? '',
      'time': timeStr,
    };
  }

  // --- スレッド一覧＋最新メッセージ情報を返す ---
  Future<List<Map<String, dynamic>>> fetchThreads({
    int maxResults = 20,
    int limit = 100,
  }) async {
    final t = await _token();
    if (t == null) return [];
    String? page;
    final out = <Map<String, dynamic>>[];

    while (out.length < limit) {
      final params = {
        'maxResults': '$maxResults',
        if (page != null) 'pageToken': page!,
      };
      final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
      if (res.statusCode != 200) {
        throw Exception('threads failed: ${res.statusCode} ${res.body}');
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final threads = (data['threads'] as List? ?? []);

      for (final th in threads) {
        if (out.length >= limit) break;
        final threadId = th['id'] as String;

        // threads.get でメッセージIDを取る
        final tUri = Uri.parse('$_base/threads/$threadId?format=metadata');
        final tRes =
            await http.get(tUri, headers: {'Authorization': 'Bearer $t'});
        if (tRes.statusCode != 200) continue;
        final tData = json.decode(tRes.body) as Map<String, dynamic>;
        final msgs = (tData['messages'] as List? ?? []);
        if (msgs.isEmpty) continue;
        final lastMsgId = (msgs.last as Map)['id'] as String;

        final summary = await _getMessageSummary(lastMsgId);
        out.add(summary);
      }

      page = data['nextPageToken'] as String?;
      if (page == null) break;
    }
    return out;
  }
}