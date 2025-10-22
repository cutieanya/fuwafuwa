// lib/ui/home_page.dart
import 'package:flutter/material.dart';
import '../data/local_db/local_db.dart';
import 'package:fuwafuwa/data/ repositories/gmail_repository.dart';
import 'package:fuwafuwa/features/chat/services/gmail_service.dart';
import 'thread_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDb.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Threads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final svc = GmailService();
              final repo = GmailRepositoryHttp(db: db, svc: svc);
              try {
                final email = await svc.myAddress() ?? '(unknown)';
                // 直近30日分のINBOXを取得して保存
                await repo.backfillInbox(
                  query: 'in:inbox newer_than:30d',
                  limit: 80,
                );

                // スレッド数のざっくり確認
                final threadCount = (await db.select(db.threads).get()).length;

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('同期OK: $email / threads: $threadCount'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('同期失敗: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Thread>>(
        stream: db.watchThreadsByLatest(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              final svc = GmailService();
              final repo = GmailRepositoryHttp(db: db, svc: svc);
              try {
                await repo.backfillInbox(
                  query: 'in:inbox newer_than:30d',
                  limit: 80,
                );
              } catch (_) {
                // Refresh時は静かに失敗してもOK
              }
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = items[i];
                final title = (t.subjectLatest?.isNotEmpty ?? false)
                    ? t.subjectLatest!
                    : '(no subject)';
                final subtitle = t.snippet ?? '';
                final right = _formatDate(t.lastMessageDate);

                return ListTile(
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ThreadPage(threadId: t.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y/$m/$day $hh:$mm';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final db = LocalDb.instance;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No threads yet'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Gmailを同期する'),
              onPressed: () async {
                final svc = GmailService();
                final repo = GmailRepositoryHttp(db: db, svc: svc);
                try {
                  final email = await svc.myAddress() ?? '(unknown)';
                  await repo.backfillInbox(
                    query: 'in:inbox newer_than:30d',
                    limit: 80,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('同期OK: $email')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('同期失敗: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
