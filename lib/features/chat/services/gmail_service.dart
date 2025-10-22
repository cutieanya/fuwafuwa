// gmail_service.dart
//
// 目的：Gmail API を http で直接叩く薄いサービス層。
// - Google Sign-In で取得したアクセストークン or authHeaders を使って REST を呼びます。
// - スレッド一覧（サマリ）と、送信元ごとのメッセージ一覧（LINE風トーク画面用）を提供。
// - サーバー側フィルタ（q=from:... OR from:... newer_than:30d 等）に対応。
// - Chat 側から refreshAuthHeaders(...) を呼べば、アカウント切替後も確実にそのアカウントで実行されます。

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GmailService {
  // REST のベース URL（me = 認証済みユーザー自身）
  static const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  // （フォールバック用）このインスタンスでサインインも可能だが、
  // 基本は refreshAuthHeaders() で渡されたヘッダを使う。
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  // ---- Chat から受け取る認証情報（優先して使う）----
  Map<String, String>?
  _authHeadersOverride; // GoogleSignInAccount.authHeaders をそのまま保持
  String? _activeEmailOverride; // 任意：現在アカウントのメールを保持（左右判定用など）

  /// Chat 側の GoogleSignIn.currentUser?.authHeaders を渡す
  /// 例: await _service.refreshAuthHeaders(await _gsi.currentUser?.authHeaders, email: _gsi.currentUser?.email);
  Future<void> refreshAuthHeaders(
    Map<String, String>? headers, {
    String? email,
  }) async {
    _authHeadersOverride = (headers == null) ? null : Map.of(headers);
    _activeEmailOverride = email?.toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // 認証ヘルパ
  // ---------------------------------------------------------------------------

  // フォールバック：自前の GoogleSignIn からアクセストークンを得る
  Future<String?> _tokenFromGSI() async {
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  // 最終的に使う HTTP ヘッダを作成（override を最優先）
  Future<Map<String, String>> _headers({bool jsonContent = false}) async {
    if (_authHeadersOverride != null &&
        _authHeadersOverride!['Authorization'] != null) {
      final h = Map<String, String>.from(_authHeadersOverride!);
      if (jsonContent) h['Content-Type'] = 'application/json';
      return h;
    }
    final t = await _tokenFromGSI();
    if (t == null) {
      throw Exception(
        'No auth header / token. Call refreshAuthHeaders() or sign in.',
      );
    }
    return {
      'Authorization': 'Bearer $t',
      if (jsonContent) 'Content-Type': 'application/json',
    };
  }

  // 自分の Gmail アドレス（UI の左右判定に使用したい場合）
  Future<String?> myAddress() async {
    if (_activeEmailOverride != null) return _activeEmailOverride;
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    return account?.email.toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // メールアドレス正規化 & クエリ生成
  // ---------------------------------------------------------------------------

  // "表示名 <addr@ex.com>" / "addr@ex.com" いずれからもメールアドレスだけを抜き出し、lowercase に
  String _normalizeEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return (m?.group(1) ?? raw).trim().toLowerCase();
  }

  /// 送信元の配列から Gmail 検索クエリを生成
  /// 例) ['a@x','b@x'] -> 'from:a@x OR from:b@x'
  /// newerThan は '7d' / '30d' / '3m' / '1y' など（Gmail の高度な検索構文）
  String _buildFromQuery(List<String> senders, {String? newerThan}) {
    final parts = senders
        .where((e) => e.trim().isNotEmpty)
        .map(_normalizeEmail)
        .map((e) => 'from:$e')
        .toList();
    String q = parts.join(' OR ');
    if (q.isEmpty) return '';
    if (newerThan != null && newerThan.trim().isNotEmpty) {
      q = '($q) newer_than:${newerThan.trim()}';
    }
    return q;
  }

  // ---------------------------------------------------------------------------
  // メッセージ1件をサマリへ（From / Date / snippet など）
  // - バブル表示のために fromEmail / timeDt も返却
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _getMessageSummary(String messageId) async {
    final uri = Uri.parse(
      '$_base/messages/$messageId'
      '?format=metadata'
      '&metadataHeaders=From'
      '&metadataHeaders=Date',
    );

    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('getMessage failed: ${res.statusCode} ${res.body}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;

    // internalDate はエポックms（UTC）
    final internalMs = int.tryParse('${data['internalDate'] ?? ''}');
    final date = internalMs != null
        ? DateTime.fromMillisecondsSinceEpoch(internalMs, isUtc: true).toLocal()
        : null;

    // From
    String? fromHeader;
    final headers = (data['payload']?['headers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    for (final h in headers) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final value = (h['value'] ?? '').toString();
      if (name == 'from') fromHeader = value;
    }

    String fromName = '(unknown)';
    String fromEmail = '';
    if (fromHeader != null && fromHeader!.isNotEmpty) {
      final m = RegExp(r'^(.*)<\s*([^>]+)\s*>$').firstMatch(fromHeader!);
      if (m != null) {
        fromName = (m.group(1) ?? '').trim().replaceAll('"', '');
        fromEmail = (m.group(2) ?? '').trim().toLowerCase();
        if (fromName.isEmpty) fromName = fromEmail;
      } else {
        fromEmail = fromHeader!.trim().toLowerCase();
        fromName = fromEmail;
      }
    }

    String timeStr = '';
    if (date != null) {
      timeStr =
          '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return {
      'id': data['id'],
      'threadId': data['threadId'],
      'from': fromName,
      'fromEmail': fromEmail,
      'snippet': data['snippet'] ?? '',
      'time': timeStr,
      'timeDt': date,
    };
  }

  // ---------------------------------------------------------------------------
  // スレッド一覧 + 各スレッドの最新メッセージのサマリ
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchThreads({
    String? query, // 例：'from:a@x OR from:b@x newer_than:30d'
    int maxResults = 20,
    int limit = 100,
  }) async {
    String? pageToken;
    final out = <Map<String, dynamic>>[];

    while (out.length < limit) {
      final params = <String, String>{
        'maxResults': '$maxResults',
        if (pageToken != null) 'pageToken': pageToken!,
        if (query != null && query.trim().isNotEmpty) 'q': query!,
      };

      final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode != 200) {
        throw Exception('threads failed: ${res.statusCode} ${res.body}');
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final threads = (data['threads'] as List? ?? []);

      // 各スレッドの最新メッセージ1通を取得
      for (final th in threads) {
        if (out.length >= limit) break;

        final threadId = th['id'] as String;
        final tUri = Uri.parse('$_base/threads/$threadId?format=metadata');
        final tRes = await http.get(tUri, headers: await _headers());
        if (tRes.statusCode != 200) continue;

        final tData = json.decode(tRes.body) as Map<String, dynamic>;
        final msgs = (tData['messages'] as List? ?? []);
        if (msgs.isEmpty) continue;

        final lastMsgId = (msgs.last as Map)['id'] as String;
        final summary = await _getMessageSummary(lastMsgId);
        if (summary.isNotEmpty) out.add(summary);
      }

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null) break;
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // 送信元で絞ってスレッド一覧を取得（ChatList 用）
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchThreadsBySenders({
    required List<String> senders,
    String? newerThan,
    int maxResults = 20,
    int limit = 100,
    int chunkSize = 15,
  }) async {
    // 正規化＆重複排除
    final normalized = {for (final s in senders) _normalizeEmail(s)}
      ..removeWhere((e) => e.isEmpty);

    if (normalized.isEmpty) return [];

    final all = <Map<String, dynamic>>[];
    final seenThreadIds = <String>{};
    final list = normalized.toList();

    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.sublist(i, (i + chunkSize).clamp(0, list.length));
      final q = _buildFromQuery(chunk, newerThan: newerThan);
      if (q.isEmpty) continue;

      final remaining = limit - all.length;
      if (remaining <= 0) break;

      final part = await fetchThreads(
        query: q,
        maxResults: maxResults,
        limit: remaining,
      );

      for (final m in part) {
        final tid = (m['threadId'] ?? m['id'] ?? '').toString();
        if (tid.isEmpty || seenThreadIds.contains(tid)) continue;
        seenThreadIds.add(tid);
        all.add(m);
        if (all.length >= limit) break;
      }
      if (all.length >= limit) break;
    }

    return all;
  }

  // ---------------------------------------------------------------------------
  // 未読カウント
  // ---------------------------------------------------------------------------
  Future<int> countUnreadBySender(
    String senderEmail, {
    String? newerThan, // 例: '30d'
    int pageSize = 50,
    int capPerSender = 500,
  }) async {
    final email = senderEmail.trim().toLowerCase();
    if (email.isEmpty) return 0;

    String q = 'from:$email is:unread';
    if (newerThan != null && newerThan.trim().isNotEmpty) {
      q = '($q) newer_than:${newerThan.trim()}';
    }

    int count = 0;
    String? pageToken;

    while (true) {
      final params = <String, String>{
        'q': q,
        'maxResults': '$pageSize',
        if (pageToken != null) 'pageToken': pageToken!,
      };

      // スレッド単位でカウント
      final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode != 200) {
        break; // 失敗時は 0 扱い
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final threads = (data['threads'] as List? ?? []);
      count += threads.length;

      if (count >= capPerSender) {
        count = capPerSender;
        break;
      }

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null || threads.isEmpty) break;
    }

    return count;
  }

  /// 複数送信元の未読件数をまとめて取得
  Future<Map<String, int>> countUnreadBySenders(
    List<String> senders, {
    String? newerThan,
    int pageSize = 50,
    int capPerSender = 500,
  }) async {
    final map = <String, int>{};
    for (final s in senders) {
      final email = _normalizeEmail(s);
      if (email.isEmpty) continue;
      final n = await countUnreadBySender(
        email,
        newerThan: newerThan,
        pageSize: pageSize,
        capPerSender: capPerSender,
      );
      map[email] = n;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // 送信元のメッセージ一覧（PersonChat 用）
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchMessagesBySender(
    String senderEmail, {
    String? newerThan, // 例: '6m'
    int maxResults = 50,
    int limit = 300,
  }) async {
    final email = senderEmail.trim().toLowerCase();
    if (email.isEmpty) return [];

    String q = 'from:$email';
    if (newerThan != null && newerThan.trim().isNotEmpty) {
      q = '($q) newer_than:${newerThan.trim()}';
    }

    final out = <Map<String, dynamic>>[];
    String? pageToken;

    while (out.length < limit) {
      final params = <String, String>{
        'q': q,
        'maxResults': '$maxResults',
        if (pageToken != null) 'pageToken': pageToken!,
      };
      final listUri = Uri.parse(
        '$_base/messages',
      ).replace(queryParameters: params);

      final listRes = await http.get(listUri, headers: await _headers());
      if (listRes.statusCode != 200) {
        throw Exception(
          'messages.list failed: ${listRes.statusCode} ${listRes.body}',
        );
      }

      final listData = json.decode(listRes.body) as Map<String, dynamic>;
      final ids = (listData['messages'] as List? ?? [])
          .cast<Map>()
          .map((m) => m['id'] as String)
          .toList();

      for (final id in ids) {
        if (out.length >= limit) break;
        final summary = await _getMessageSummary(id);
        if (summary.isNotEmpty) out.add(summary);
      }

      pageToken = listData['nextPageToken'] as String?;
      if (pageToken == null) break;
    }

    // 「古い→新しい」の昇順
    out.sort((a, b) {
      final da = a['timeDt'] as DateTime?;
      final db = b['timeDt'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });

    return out;
  }

  // ---------------------------------------------------------------------------
  // 既読化
  // ---------------------------------------------------------------------------

  /// 1通を既読にする（UNREADラベルを外す）
  Future<void> markMessageRead(String messageId) async {
    final uri = Uri.parse('$_base/messages/$messageId/modify');
    final body = {
      'removeLabelIds': ['UNREAD'],
    };
    final res = await http.post(
      uri,
      headers: await _headers(jsonContent: true),
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('markMessageRead failed: ${res.statusCode} ${res.body}');
    }
  }

  /// スレッド全体を既読にする（スレッド内の各メッセージから UNREAD を外す）
  Future<void> markThreadRead(String threadId) async {
    final uri = Uri.parse('$_base/threads/$threadId/modify');
    final body = {
      'removeLabelIds': ['UNREAD'],
    };
    final res = await http.post(
      uri,
      headers: await _headers(jsonContent: true),
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('markThreadRead failed: ${res.statusCode} ${res.body}');
    }
  }

  /// クエリに一致する未読メールを一括で既読にする
  /// - 例: q='from:foo@example.com is:unread newer_than:90d'
  /// - メッセージIDを検索 → batchModify
  Future<int> markReadByQuery(String q, {int pageSize = 100}) async {
    // まず ids 収集
    final ids = <String>[];
    String? pageToken;

    while (true) {
      final params = <String, String>{
        'q': q,
        'maxResults': '$pageSize',
        if (pageToken != null) 'pageToken': pageToken!,
      };
      final listUri = Uri.parse(
        '$_base/messages',
      ).replace(queryParameters: params);
      final listRes = await http.get(listUri, headers: await _headers());
      if (listRes.statusCode != 200) break;

      final data = json.decode(listRes.body) as Map<String, dynamic>;
      final msgs = (data['messages'] as List? ?? []);
      ids.addAll(msgs.map((e) => (e as Map)['id'] as String));

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null || msgs.isEmpty) break;
    }

    if (ids.isEmpty) return 0;

    // まとめて既読化（batchModify）
    final batchUri = Uri.parse('$_base/messages/batchModify');
    final body = {
      'ids': ids,
      'removeLabelIds': ['UNREAD'],
    };
    final batchRes = await http.post(
      batchUri,
      headers: await _headers(jsonContent: true),
      body: json.encode(body),
    );
    if (batchRes.statusCode != 200) {
      throw Exception(
        'batchModify failed: ${batchRes.statusCode} ${batchRes.body}',
      );
    }
    return ids.length;
  }
}
