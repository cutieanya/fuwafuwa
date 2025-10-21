import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Gmail API 送信ユーティリティ
///
/// - テキスト/HTML（multipart/alternative）
/// - 返信ヘッダ In-Reply-To / References
/// - CC / BCC
/// - sendEmail は Gmail のレスポンス JSON を Map で返す
class GmailSendService {
  /// 旧API互換: 単純テキストのMIME生成（必要に応じて返信ヘッダ付与）
  String createMimeMessage({
    required String to,
    required String from,
    required String subject,
    required String body,
    String? inReplyTo,
    String? references,
    List<String>? cc,
    List<String>? bcc,
  }) {
    return _encodeRawMime(
      _buildSinglePartTextMime(
        to: to,
        from: from,
        subject: subject,
        textBody: body,
        inReplyTo: inReplyTo,
        references: references,
        cc: cc,
        bcc: bcc,
      ),
    );
  }

  /// 推奨: テキスト/HTML両対応のMIME生成
  String buildMimeMessage({
    required String to,
    required String from,
    required String subject,
    String? textBody,
    String? htmlBody,
    List<String>? cc,
    List<String>? bcc,
    String? inReplyTo,
    String? references,
    String? messageId,
    DateTime? date,
  }) {
    if ((textBody == null || textBody.isEmpty) &&
        (htmlBody == null || htmlBody.isEmpty)) {
      throw ArgumentError('textBody か htmlBody のどちらかは必須です。');
    }

    final raw = (textBody != null && htmlBody != null)
        ? _buildMultipartAlternativeMime(
            to: to,
            from: from,
            subject: subject,
            textBody: textBody,
            htmlBody: htmlBody,
            cc: cc,
            bcc: bcc,
            inReplyTo: inReplyTo,
            references: references,
            messageId: messageId,
            date: date,
          )
        : _buildSinglePartTextOrHtmlMime(
            to: to,
            from: from,
            subject: subject,
            body: textBody ?? htmlBody!,
            isHtml: htmlBody != null,
            cc: cc,
            bcc: bcc,
            inReplyTo: inReplyTo,
            references: references,
            messageId: messageId,
            date: date,
          );

    return _encodeRawMime(raw);
  }

  /// Gmail API: messages.send（成功時はレスポンスJSONを返す）
  Future<Map<String, dynamic>> sendEmail({
    required Map<String, String> authHeaders,
    required String rawMessage,
    String? threadId,
  }) async {
    final uri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
    );

    final payload = <String, dynamic>{
      'raw': rawMessage,
      if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
    };

    final res = await http.post(
      uri,
      headers: {...authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw GmailSendException(
        statusCode: res.statusCode,
        body: res.body,
        message: 'Gmail API messages.send 失敗',
      );
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ===== 内部ヘルパ =====

  String _encodeRawMime(String raw) {
    return base64UrlEncode(utf8.encode(raw)).replaceAll('=', '');
    // GmailはURL-safe base64（パディングなし）を要求
  }

  String _encodeHeaderUtf8(String value) {
    final b64 = base64Encode(utf8.encode(value));
    return '=?UTF-8?B?$b64?=';
  }

  String _formatRfc2822Date(DateTime dt) {
    final wdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final utc = dt.toUtc();
    final wd = wdays[utc.weekday % 7]; // Monday=1 → 0-based
    final mm = months[utc.month - 1];
    final hh = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$wd, ${utc.day.toString().padLeft(2, '0')} $mm ${utc.year} $hh:$mi:$ss +0000';
  }

  String _generateMessageId() {
    final rand = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = List.generate(16, (_) => rand.nextInt(256));
    final token = base64UrlEncode(r).replaceAll('=', '');
    return '<$ts.$token@local>';
  }

  String _joinEmails(List<String>? list) =>
      (list == null || list.isEmpty) ? '' : list.join(', ');

  String _buildSinglePartTextMime({
    required String to,
    required String from,
    required String subject,
    required String textBody,
    List<String>? cc,
    List<String>? bcc,
    String? inReplyTo,
    String? references,
    String? messageId,
    DateTime? date,
  }) {
    final headers = <String>[
      'From: $from',
      'To: $to',
      if (cc != null && cc.isNotEmpty) 'Cc: ${_joinEmails(cc)}',
      if (bcc != null && bcc.isNotEmpty) 'Bcc: ${_joinEmails(bcc)}',
      'Subject: ${_encodeHeaderUtf8(subject)}',
      'MIME-Version: 1.0',
      'Date: ${_formatRfc2822Date(date ?? DateTime.now())}',
      'Content-Type: text/plain; charset="UTF-8"',
      'Content-Transfer-Encoding: 8bit',
      if (inReplyTo != null && inReplyTo.isNotEmpty) 'In-Reply-To: $inReplyTo',
      if (references != null && references.isNotEmpty)
        'References: $references',
      'Message-ID: ${messageId ?? _generateMessageId()}',
    ];

    return [...headers, '', textBody].join('\r\n');
  }

  String _buildSinglePartTextOrHtmlMime({
    required String to,
    required String from,
    required String subject,
    required String body,
    required bool isHtml,
    List<String>? cc,
    List<String>? bcc,
    String? inReplyTo,
    String? references,
    String? messageId,
    DateTime? date,
  }) {
    final contentType = isHtml
        ? 'text/html; charset="UTF-8"'
        : 'text/plain; charset="UTF-8"';

    final headers = <String>[
      'From: $from',
      'To: $to',
      if (cc != null && cc.isNotEmpty) 'Cc: ${_joinEmails(cc)}',
      if (bcc != null && bcc.isNotEmpty) 'Bcc: ${_joinEmails(bcc)}',
      'Subject: ${_encodeHeaderUtf8(subject)}',
      'MIME-Version: 1.0',
      'Date: ${_formatRfc2822Date(date ?? DateTime.now())}',
      'Content-Type: $contentType',
      'Content-Transfer-Encoding: 8bit',
      if (inReplyTo != null && inReplyTo.isNotEmpty) 'In-Reply-To: $inReplyTo',
      if (references != null && references.isNotEmpty)
        'References: $references',
      'Message-ID: ${messageId ?? _generateMessageId()}',
    ];

    return [...headers, '', body].join('\r\n');
  }

  String _buildMultipartAlternativeMime({
    required String to,
    required String from,
    required String subject,
    required String textBody,
    required String htmlBody,
    List<String>? cc,
    List<String>? bcc,
    String? inReplyTo,
    String? references,
    String? messageId,
    DateTime? date,
  }) {
    final boundary = _randomBoundary();
    final headers = <String>[
      'From: $from',
      'To: $to',
      if (cc != null && cc.isNotEmpty) 'Cc: ${_joinEmails(cc)}',
      if (bcc != null && bcc.isNotEmpty) 'Bcc: ${_joinEmails(bcc)}',
      'Subject: ${_encodeHeaderUtf8(subject)}',
      'MIME-Version: 1.0',
      'Date: ${_formatRfc2822Date(date ?? DateTime.now())}',
      'Content-Type: multipart/alternative; boundary="$boundary"',
      if (inReplyTo != null && inReplyTo.isNotEmpty) 'In-Reply-To: $inReplyTo',
      if (references != null && references.isNotEmpty)
        'References: $references',
      'Message-ID: ${messageId ?? _generateMessageId()}',
    ];

    final parts = <String>[
      '--$boundary',
      'Content-Type: text/plain; charset="UTF-8"',
      'Content-Transfer-Encoding: 8bit',
      '',
      textBody,
      '--$boundary',
      'Content-Type: text/html; charset="UTF-8"',
      'Content-Transfer-Encoding: 8bit',
      '',
      htmlBody,
      '--$boundary--',
      '',
    ];

    return [...headers, '', ...parts].join('\r\n');
  }

  String _randomBoundary() {
    final rand = Random();
    final bytes = List<int>.generate(18, (_) => rand.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    return 'dart-mail-boundary-$token';
  }
}

class GmailSendException implements Exception {
  final int statusCode;
  final String body;
  final String message;

  GmailSendException({
    required this.statusCode,
    required this.body,
    required this.message,
  });

  @override
  String toString() => 'GmailSendException($statusCode): $message\n$body';
}
