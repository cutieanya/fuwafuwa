// gmail_service.dart
//
// 目的：Gmail API を http で直接叩く薄いサービス層。
// - Google Sign-In で取得したアクセストークンを使って REST を呼びます。
// - スレッド一覧（サマリ）と、送信元ごとのメッセージ一覧（LINE風トーク画面用）を提供。
// - サーバー側フィルタ（q=from:... OR from:... newer_than:30d 等）に対応。
//
// 注意：本ファイルは UI を持ちません。画面側（ChatListScreen / PersonChatScreen）から
//       このサービスの関数を呼んでデータを受け取り、UI に反映します。

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GmailService {
  // Google サインインのインスタンス。
  // - scopes に Gmail の権限を付与（閲覧のみなら gmail.readonly でOK）
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
      // もし既読変更や送信も扱うなら modify スコープを追加してください：
      // 'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  // REST のベース URL（me = 認証済みユーザー自身）
  static const _base = 'https://gmail.googleapis.com/gmail/v1/users/me';

  // ---------------------------------------------------------------------------
  // 認証ヘルパ：アクセストークンを取得
  // ---------------------------------------------------------------------------
  Future<String?> _token() async {
    // 既にサインイン済みであればサイレントに。そうでなければUIでサインイン。
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken; // Bearer トークンを返却
  }

  // 自分の Gmail アドレス（UI で「自分⇔相手」の左右判定に使う）
  Future<String?> myAddress() async {
    final account = await _gsi.signInSilently() ?? await _gsi.signIn();
    return account?.email?.toLowerCase();
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
  /// newerThan は '7d' / '30d' / '3m' / '1y' などを想定（Gmail の高度な検索構文）
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
  // - バブル表示のために fromEmail / timeDt も返却（左右判定や時刻整列に便利）
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _getMessageSummary(String messageId) async {
    final t = await _token();
    if (t == null) return {};

    // メタデータ形式：本文本体は取得せず、必要なヘッダだけもらう
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

    // internalDate はエポックms（UTC）→ 端末ローカルへ
    final internalMs = int.tryParse('${data['internalDate'] ?? ''}');
    final date = internalMs != null
        ? DateTime.fromMillisecondsSinceEpoch(internalMs, isUtc: true).toLocal()
        : null;

    // ヘッダから From を抽出
    String? fromHeader;
    final headers = (data['payload']?['headers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    for (final h in headers) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final value = (h['value'] ?? '').toString();
      if (name == 'from') fromHeader = value;
    }

    // From を表示名とメールに分割
    String fromName = '(unknown)';
    String fromEmail = '';
    if (fromHeader != null && fromHeader!.isNotEmpty) {
      final m = RegExp(r'^(.*)<\s*([^>]+)\s*>$').firstMatch(fromHeader!);
      if (m != null) {
        fromName = (m.group(1) ?? '').trim().replaceAll('"', '');
        fromEmail = (m.group(2) ?? '').trim().toLowerCase();
        if (fromName.isEmpty) fromName = fromEmail;
      } else {
        // "addr@ex.com" のみ
        fromEmail = fromHeader!.trim().toLowerCase();
        fromName = fromEmail;
      }
    }

    // 一覧に出す簡易時刻文字列（細かいローカライズはUI側で）
    String timeStr = '';
    if (date != null) {
      timeStr =
          '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return {
      'id': data['id'],
      'threadId': data['threadId'],
      'from': fromName, // 表示名
      'fromEmail': fromEmail, // メールアドレス（左右判定に有用）
      'snippet': data['snippet'] ?? '',
      'time': timeStr, // 一覧用の文字列
      'timeDt': date, // DateTime（並び替え/同分判定などに）
    };
  }

  // ---------------------------------------------------------------------------
  // スレッド一覧 + 各スレッドの最新メッセージのサマリ
  // - query を渡すと Gmail 側で検索（q=...）
  // - ページングも吸収（nextPageToken）
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchThreads({
    String? query, // 例：'from:a@x OR from:b@x newer_than:30d'
    int maxResults = 20, // list 1回の取得上限（Gmailの page size）
    int limit = 100, // 全体の最大件数（画面要件に合わせて調整）
  }) async {
    final t = await _token();
    if (t == null) return [];

    String? pageToken;
    final out = <Map<String, dynamic>>[];

    while (out.length < limit) {
      final params = <String, String>{
        'maxResults': '$maxResults',
        if (pageToken != null) 'pageToken': pageToken!,
        if (query != null && query.trim().isNotEmpty) 'q': query!,
      };

      final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
      if (res.statusCode != 200) {
        throw Exception('threads failed: ${res.statusCode} ${res.body}');
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final threads = (data['threads'] as List? ?? []);

      // 各スレッドの「最新メッセージ1通」を取り、そのサマリを out に追加
      for (final th in threads) {
        if (out.length >= limit) break;

        final threadId = th['id'] as String;
        final tUri = Uri.parse('$_base/threads/$threadId?format=metadata');
        final tRes = await http.get(
          tUri,
          headers: {'Authorization': 'Bearer $t'},
        );
        if (tRes.statusCode != 200) continue;

        final tData = json.decode(tRes.body) as Map<String, dynamic>;
        final msgs = (tData['messages'] as List? ?? []);
        if (msgs.isEmpty) continue;

        final lastMsgId = (msgs.last as Map)['id'] as String;
        final summary = await _getMessageSummary(lastMsgId);
        if (summary.isNotEmpty) out.add(summary);
      }

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null) break; // もう次のページが無い
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // 送信元で絞ってスレッド一覧を取得（ChatList 用）
  // - 送信元が大量の場合、クエリ長対策でチャンクに分割して複数回呼ぶ
  // - 重複スレッドは threadId で除去
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchThreadsBySenders({
    required List<String> senders, // 表示したい送信元
    String? newerThan, // 例: '30d'（任意）
    int maxResults = 20,
    int limit = 100,
    int chunkSize = 15, // 送信元が多い時に何件ずつ OR で束ねるか
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

      // 残り必要数に合わせて取得
      final remaining = limit - all.length;
      if (remaining <= 0) break;

      final part = await fetchThreads(
        query: q,
        maxResults: maxResults,
        limit: remaining,
      );

      // スレッド重複を除外
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

  Future<int> countUnreadBySender(
    String senderEmail, {
    String? newerThan, // 例: '30d'
    int pageSize = 50, // 1ページの最大件数
    int capPerSender = 500, // これ以上は「99+」的に丸める想定
  }) async {
    final t = await _token();
    if (t == null) return 0;

    final email = senderEmail.trim().toLowerCase();
    if (email.isEmpty) return 0;

    // クエリ例： (from:foo@bar) is:unread newer_than:30d
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

      // スレッド単位で数える（1スレッドに未読があれば1カウント）
      final uri = Uri.parse('$_base/threads').replace(queryParameters: params);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $t'});
      if (res.statusCode != 200) {
        // 失敗時は 0 とする（UI 側で未読バッジ無しになる）
        break;
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final threads = (data['threads'] as List? ?? []);
      count += threads.length;

      // 上限キャップ
      if (count >= capPerSender) {
        count = capPerSender;
        break;
      }

      pageToken = data['nextPageToken'] as String?;
      if (pageToken == null || threads.isEmpty) break;
    }

    return count;
  }

  /// 複数送信元の未読件数をまとめて取得（順次実行・適度に速い）
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
  // 送信元の“メッセージ一覧”を取得（PersonChat 用：LINE風トーク画面）
  // - Gmail の messages.list に q=from:sender を渡す
  // - 各メッセージを _getMessageSummary で軽量取得して時系列昇順で返す
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchMessagesBySender(
    String senderEmail, {
    String? newerThan, // 例: '6m'
    int maxResults = 50, // list 1回の取得上限
    int limit = 300, // 取得総数の上限（無限に取らない安全装置）
  }) async {
    final t = await _token();
    if (t == null) return [];

    final email = senderEmail.trim().toLowerCase();
    if (email.isEmpty) return [];

    // q を作成（例：'(from:a@x) newer_than:6m'）
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

      final listRes = await http.get(
        listUri,
        headers: {'Authorization': 'Bearer $t'},
      );
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
      if (pageToken == null) break; // 次ページが無ければ終了
    }

    // バブル表示では「古い→新しい」の昇順が自然
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
  // gmail_service.dart（GmailService クラスの中に追記）

  /// 1通を既読にする（UNREADラベルを外す）
  Future<void> markMessageRead(String messageId) async {
    final t = await _token();
    if (t == null) return;
    final uri = Uri.parse('$_base/messages/$messageId/modify');
    final body = {
      'removeLabelIds': ['UNREAD'],
    };
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('markMessageRead failed: ${res.statusCode} ${res.body}');
    }
  }

  /// スレッド全体を既読にする（スレッド内の各メッセージから UNREAD を外す）
  Future<void> markThreadRead(String threadId) async {
    final t = await _token();
    if (t == null) return;
    final uri = Uri.parse('$_base/threads/$threadId/modify');
    final body = {
      'removeLabelIds': ['UNREAD'],
    };
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
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
    final t = await _token();
    if (t == null) return 0;

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
      final listRes = await http.get(
        listUri,
        headers: {'Authorization': 'Bearer $t'},
      );
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
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
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
