import 'package:flutter/material.dart';
import 'package:fuwafuwa/data/local_db/local_db.dart';

class EmailDetailScreen extends StatefulWidget {
  final String messageId;
  const EmailDetailScreen({super.key, required this.messageId});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  Future<_EmailViewModel> _load() async {
    final db = LocalDb.instance;
    final m = db.messages;

    final row = await (db.select(
      m,
    )..where((t) => t.id.equals(widget.messageId))).getSingleOrNull();

    if (row == null) {
      return _EmailViewModel(
        subject: '(Not found)',
        from: '',
        to: '',
        date: null,
        snippet: '',
        bodyPlain: '',
        bodyHtml: '',
      );
    }

    return _EmailViewModel(
      subject: row.subject ?? '',
      from: row.from ?? '',
      to: row.to ?? '',
      date: row.internalDate,
      snippet: row.snippet ?? '',
      bodyPlain: row.bodyPlain ?? '',
      bodyHtml: row.bodyHtml ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: FutureBuilder<_EmailViewModel>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting ||
              snap.connectionState == ConnectionState.none) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final vm = snap.data!;
          final dateStr = _formatTime(vm.date);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // 件名
              Text(
                vm.subject.isEmpty ? '(No subject)' : vm.subject,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),

              // 差出人/宛先/日付
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'From', vm.from),
                      const SizedBox(height: 6),
                      _kv(context, 'To', vm.to.isEmpty ? '(unknown)' : vm.to),
                      const SizedBox(height: 6),
                      _kv(context, 'Date', dateStr),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 本文（HTMLがあれば簡易テキスト化、なければプレーン→スニペット）
              _EmailBody(vm: vm),
            ],
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }

  Widget _kv(BuildContext context, String k, String v) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$k: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: v),
        ],
      ),
    );
  }
}

class _EmailViewModel {
  final String subject;
  final String from;
  final String to;
  final DateTime? date;
  final String snippet;
  final String bodyPlain;
  final String bodyHtml;
  _EmailViewModel({
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.snippet,
    required this.bodyPlain,
    required this.bodyHtml,
  });
}

class _EmailBody extends StatelessWidget {
  final _EmailViewModel vm;
  const _EmailBody({required this.vm});

  // 超簡易HTML→テキスト
  String _htmlToRoughText(String html) {
    if (html.isEmpty) return '';
    final noHead = html.replaceAll(
      RegExp(r'(?is)<(script|style)[\s\S]*?</\1>'),
      '',
    );
    final stripped = noHead.replaceAll(RegExp(r'(?is)<[^>]+>'), '');
    return stripped.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
  }

  @override
  Widget build(BuildContext context) {
    final body = vm.bodyHtml.isNotEmpty
        ? _htmlToRoughText(vm.bodyHtml)
        : (vm.bodyPlain.isNotEmpty ? vm.bodyPlain : vm.snippet);

    return SelectableText(
      body.isEmpty ? '(本文が保存されていません)' : body,
      style: const TextStyle(fontSize: 16, height: 1.45),
    );
  }
}
