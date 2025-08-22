import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

/// Gmail API を手軽に使うための薄いラッパ
/// - 認証は google_sign_in(v5.4.4) でユーザー承認→アクセストークン取得
/// - スコープは readonly のまま（送信/削除は不可）。必要なら適宜追加してください。
class GmailService {
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      // 例: 'https://www.googleapis.com/auth/gmail.modify',
      // 例: 'https://www.googleapis.com/auth/gmail.send',
    ],
  );

  static const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  /// 現在のユーザーのアクセストークンを取得
  Future<String?> getAccessToken() async {
    final GoogleSignInAccount? account =
        await _gsi.signInSilently() ?? await _gsi.signIn();
    if (account == null) return null;
    final GoogleSignInAuthentication auth = await account.authentication;
    return auth.accessToken;
  }

  /// 共通 GET ヘルパ
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final token = await getAccessToken();
    if (token == null) {
      throw StateError('Not signed in');
    }
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('GET ${uri.path} failed: ${res.statusCode} ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// メッセージ一覧（IDとsnippet）
  Future<List<Map<String, String>>> listMessages({
    String? q,
    int maxResults = 20,
    String? pageToken,
  }) async {
    final params = <String, String>{
      'maxResults': '$maxResults',
      if (q != null && q.isNotEmpty) 'q': q,
      if (pageToken != null) 'pageToken': pageToken,
    };
    final uri = Uri.parse('$_base/messages').replace(queryParameters: params);
    final data = await _getJson(uri);
    final List msgs = (data['messages'] as List?) ?? [];
    // 各IDのsnippetを個別取得（必要最低限）
    final results = <Map<String, String>>[];
    for (final m in msgs) {
      final id = m['id'] as String;
      final full = await getMessage(id, format: 'metadata');
      results.add({'id': id, 'snippet': full['snippet'] as String? ?? ''});
    }
    return results;
  }

  /// メッセージ1件取得
  /// format: 'full' | 'metadata' | 'minimal' | 'raw'
  Future<Map<String, dynamic>> getMessage(String id, {String format = 'full'}) async {
    final uri = Uri.parse('$_base/messages/$id').replace(queryParameters: {'format': format});
    return _getJson(uri);
  }

  /// スレッド一覧（idとsnippet）
  Future<List<Map<String, String>>> listThreads({
    String? q,
    int maxResults = 20,
    String? pageToken,
  }) async {
    final params = <String, String>{
      'maxResults': '$maxResults',
      if (q != null && q.isNotEmpty) 'q': q,
      if (pageToken != null) 'pageToken': pageToken,
    };
    final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
    final data = await _getJson(uri);
    final List ths = (data['threads'] as List?) ?? [];
    final results = <Map<String, String>>[];
    for (final t in ths) {
      final id = t['id'] as String;
      final thr = await getThread(id, format: 'metadata');
      final snippet = thr['messages']?[0]?['snippet'] as String? ?? '';
      results.add({'id': id, 'snippet': snippet});
    }
    return results;
  }

  /// スレッド1件取得
  Future<Map<String, dynamic>> getThread(String id, {String format = 'full'}) async {
    final uri = Uri.parse('$_base/threads/$id').replace(queryParameters: {'format': format});
    return _getJson(uri);
  }

  /// ラベル一覧
  Future<List<Map<String, String>>> listLabels() async {
    final uri = Uri.parse('$_base/labels');
    final data = await _getJson(uri);
    final List labs = (data['labels'] as List?) ?? [];
    return labs.map<Map<String, String>>((e) => {
      'id': (e['id'] ?? '') as String,
      'name': (e['name'] ?? '') as String,
    }).toList();
  }

  /// 互換用（旧サンプル名）：メッセージID一覧
  Future<List<String>> fetchGmailMessages() async {
    final res = await listMessages(maxResults: 20);
    return res.map((e) => e['id'] ?? '').where((e) => e.isNotEmpty).toList();
  }

  /// 互換用（ご要望に合わせて追加）：スレッドID一覧
  Future<List<Map<String, dynamic>>> fetchThreads({int maxResults = 20}) async {
  final res = await listThreads(maxResults: maxResults); 
  // res は List<Map<String,String>> になっている想定
  return res.map<Map<String, dynamic>>((e) => {
        'id': e['id'] ?? '',
        'snippet': e['snippet'] ?? '',
      }).toList();
}
}
