// lib/gmail_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:enough_mail/enough_mail.dart';

class GmailSendService {
  /// MIMEメッセージを作成し、Base64Urlエンコードして返すメソッド
  String createMimeMessage({
    required String to,
    required String from,
    required String subject,
    required String body,
  }) {
    // 1. enough_mailのMessageBuilderでMimeMessageオブジェクトを作成
    final builder = MessageBuilder()
      ..from = [MailAddress(null, from)]
      ..to = [MailAddress(null, to)]
      ..subject = subject
      ..text = body;
    final mimeMessage = builder.buildMimeMessage();

    // 2. オブジェクトからMIME形式のヘッダーと本文を結合して、完全なメール文字列を生成
    // これがAPIが要求する「生データ」
    final rawEmailString = mimeMessage.renderMessage();

    // 3. メッセージ全体をUTF-8のバイトにエンコード
    final messageBytes = utf8.encode(rawEmailString);

    // 4. バイトデータをBase64Urlエンコードして返す
    return base64Url.encode(messageBytes);
  }

  /// Gmail APIを使ってメールを送信する (このメソッドは変更ありません)
  Future<bool> sendEmail({
    required Map<String, String> authHeaders,
    required String rawMessage,
  }) async {
    final url = Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/send');
    try {
      final response = await http.post(
        url,
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'raw': rawMessage,
        }),
      );

      if (response.statusCode == 200) {
        print('メールの送信に成功しました。');
        return true;
      } else {
        print('メールの送信に失敗しました！: ${response.body}');
        return false;
      }
    } catch (e) {
      print('HTTPリクエスト中にエラーが発生しました: $e');
      return false;
    }
  }
}