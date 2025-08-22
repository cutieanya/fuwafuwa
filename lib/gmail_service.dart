import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GmailService {
  static const String _base = 'https://gmail.googleapis.com/gmail/v1';

  // v5: 自前のインスタンス（Gmailスコープを明示）
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const ['email', 'https://www.googleapis.com/auth/gmail.readonly'],
  );

  Future<List<Map<String, dynamic>>> fetchThreads({String query = ''}) async {
    // サインイン済みがあれば再利用、なければ signIn() で取得
    final account = _gsi.currentUser ?? await _gsi.signIn();
    if (account == null) throw Exception('Googleサインインがキャンセルされました');

    // ここで Google の accessToken を取得（v5 はOK）
    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google accessToken を取得できませんでした');
    }

    // threads.list
    final listUri = Uri.parse(
      '$_base/users/me/threads${query.isNotEmpty ? '?q=$query' : ''}',
    );
    final listRes = await http.get(
      listUri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (listRes.statusCode != 200) {
      throw Exception('Gmail threads.list 失敗: ${listRes.statusCode} ${listRes.body}');
    }
    final listJson = json.decode(listRes.body) as Map<String, dynamic>;
    final threads = (listJson['threads'] as List?) ?? const [];

    // 各スレッドから、件名/差出人/スニペット/時刻を抽出
    final results = <Map<String, dynamic>>[];
    for (final t in threads) {
      final threadId = (t as Map)['id'] as String;

      final getRes = await http.get(
        Uri.parse('$_base/users/me/threads/$threadId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (getRes.statusCode != 200) continue;

      final threadJson = json.decode(getRes.body) as Map<String, dynamic>;
      final messages = (threadJson['messages'] as List?) ?? const [];
      if (messages.isEmpty) continue;

      final last = messages.last as Map<String, dynamic>;
      final payload = last['payload'] as Map<String, dynamic>?;
      final headers = (payload?['headers'] as List?) ?? const [];

      String subject = '(No subject)';
      String from = '';
      for (final h in headers) {
        final name = (h['name'] ?? '') as String;
        final value = (h['value'] ?? '') as String;
        if (name.toLowerCase() == 'subject') subject = value;
        if (name.toLowerCase() == 'from') from = value;
      }

      results.add({
        'id': threadId,
        'threadId': threadId,
        'subject': subject,
        'from': from,
        'counterpart': _extractEmail(from),
        'snippet': (last['snippet'] ?? '') as String,
        'time': _formatTime((last['internalDate'] ?? '') as String),
      });
    }
    return results;
  }

  String _extractEmail(String fromHeader) {
    final m = RegExp(
      r'<?([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})>?',
      caseSensitive: false,
    ).firstMatch(fromHeader);
    return (m?.group(1) ?? fromHeader).trim();
  }

  String _formatTime(String internalDateMillisStr) {
    try {
      final ms = int.parse(internalDateMillisStr);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return '昨日';
      } else {
        return '${dt.month}/${dt.day}';
      }
    } catch (_) {
      return '';
    }
  }
}
