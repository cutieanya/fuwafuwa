import 'package:flutter/material.dart';
import 'package:fuwafuwa/features/chat/services/gmail_send_service.dart';

class ComposeEmailScreen extends StatefulWidget {
  final String initialTo;
  final String initialFrom;
  final Map<String, String> authHeaders;
  final GmailSendService sendSvc;

  const ComposeEmailScreen({
    super.key,
    required this.initialTo,
    required this.initialFrom,
    required this.authHeaders,
    required this.sendSvc,
  });

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _toCtrl = TextEditingController();
  final _ccCtrl = TextEditingController();
  final _bccCtrl = TextEditingController();
  final _subjCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _toCtrl.text = widget.initialTo;
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _bccCtrl.dispose();
    _subjCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _toCtrl.text.trim();
    final subj = _subjCtrl.text;
    final body = _bodyCtrl.text;

    if (to.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('To は必須です')));
      return;
    }
    if (body.trim().isEmpty && subj.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('件名か本文のどちらかは入力してください')));
      return;
    }

    setState(() => _sending = true);
    try {
      // CC / BCC の分割（, or ; 区切り）
      List<String> _split(String s) {
        return s
            .split(RegExp(r'[;,]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final cc = _split(_ccCtrl.text);
      final bcc = _split(_bccCtrl.text);

      final raw = widget.sendSvc.buildMimeMessage(
        to: to,
        from: widget.initialFrom,
        subject: subj,
        textBody: body,
        cc: cc.isEmpty ? null : cc,
        bcc: bcc.isEmpty ? null : bcc,
      );

      await widget.sendSvc.sendEmail(
        authHeaders: widget.authHeaders,
        rawMessage: raw,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('送信しました')));
      Navigator.of(context).pop(); // 画面を閉じる
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送信に失敗: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規メッセージ'),
        actions: [
          TextButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('送信'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _field('From', widget.initialFrom, readOnly: true),
          const SizedBox(height: 8),
          _input('To', _toCtrl, hint: 'foo@example.com'),
          const SizedBox(height: 8),
          _input('Cc', _ccCtrl, hint: 'カンマ区切りで複数可'),
          const SizedBox(height: 8),
          _input('Bcc', _bccCtrl, hint: 'カンマ区切りで複数可'),
          const SizedBox(height: 8),
          _input('Subject', _subjCtrl, hint: '件名'),
          const SizedBox(height: 12),
          Text(
            '本文',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyCtrl,
            minLines: 8,
            maxLines: null,
            decoration: InputDecoration(
              hintText: '本文を入力',
              filled: true,
              fillColor: cs.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool readOnly = false}) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController c, {String? hint}) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
