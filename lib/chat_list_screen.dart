// chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'person_chat_screen.dart'; // 相手ごとのトーク画面
import 'gmail_service.dart'; // fetchThreadsBySenders / countUnreadBySenders

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _service = GmailService();
  final _addrController = TextEditingController();

  // Firestore ドキュメント参照（ログイン必須）
  DocumentReference<Map<String, dynamic>> get _filtersDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('未ログインです。LobbyPage からログインしてから遷移してください。');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('filters');
  }

  @override
  void dispose() {
    _addrController.dispose();
    super.dispose();
  }

  // ---------- Firestore I/O ----------
  Stream<Set<String>> _streamAllowedSenders() {
    return _filtersDoc.snapshots().map((snap) {
      final list =
          (snap.data()?['allowedSenders'] as List?)?.cast<String>() ??
          const <String>[];
      return list.map((e) => e.toLowerCase()).toSet();
    });
  }

  Future<void> _addAllowedSender(String emailRaw) async {
    final email = _extractEmail(emailRaw.trim());
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスの形式が正しくありません')));
      return;
    }
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayUnion([email]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeAllowedSender(String email) async {
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayRemove([email.toLowerCase()]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- Gmail 取得 ----------
  Future<List<Map<String, dynamic>>> _loadChatsFor(Set<String> senders) async {
    if (senders.isEmpty) return const <Map<String, dynamic>>[];
    final list = await _service.fetchThreadsBySenders(
      senders: senders.toList(),
      newerThan: '30d',
      maxResults: 20,
      limit: 200,
    );
    return _dedupBySender(list);
  }

  // 未読数まとめて取得（送信元 -> 件数）
  Future<Map<String, int>> _loadUnreadCounts(Set<String> senders) {
    if (senders.isEmpty) return Future.value(<String, int>{});
    return _service.countUnreadBySenders(
      senders.toList(),
      newerThan: '365d', // 必要に応じて期間を絞る（広くてもOK）
      pageSize: 50,
      capPerSender: 500,
    );
  }

  // ---------- 重複排除（送信元ごと最新のみ） ----------
  List<Map<String, dynamic>> _dedupBySender(List<Map<String, dynamic>> raw) {
    final bySender = <String, Map<String, dynamic>>{};

    for (final m in raw) {
      final email = ((m['fromEmail'] ?? '') as String).toLowerCase();
      final fallbackEmail = email.isNotEmpty
          ? email
          : _extractEmail((m['from'] ?? m['counterpart'] ?? '').toString()) ??
                '';
      final key = fallbackEmail;
      if (key.isEmpty) continue;

      final current = bySender[key];

      final newTime = m['timeDt'] is DateTime ? m['timeDt'] as DateTime : null;
      final curTime = (current != null && current['timeDt'] is DateTime)
          ? current['timeDt'] as DateTime
          : null;

      final shouldReplace =
          (current == null) ||
          (newTime != null && (curTime == null || newTime.isAfter(curTime)));

      if (shouldReplace) {
        bySender[key] = m..['fromEmail'] = key; // keyを確実に保持
      }
    }

    final list = bySender.values.toList();

    list.sort((a, b) {
      final da = a['timeDt'] is DateTime ? a['timeDt'] as DateTime : null;
      final db = b['timeDt'] is DateTime ? b['timeDt'] as DateTime : null;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return list;
  }

  // ---------- UI ユーティリティ ----------
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  Future<void> _showAddSenderDialog() async {
    _addrController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('表示する送信元アドレスを追加'),
        content: TextField(
          controller: _addrController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: user@example.com'),
          onSubmitted: (_) => Navigator.of(context).pop(_addrController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_addrController.text),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _addAllowedSender(result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('送信元を追加しました')));
    }
  }

  // ある senderEmail の未読を全部既読に
  Future<void> _markSenderAllRead(String senderEmail) async {
    final q =
        'from:${senderEmail.toLowerCase()} is:unread'; // 必要なら newer_than:90d など追加
    final n = await _service.markReadByQuery(q);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$n 件を既読にしました')));
    setState(() {}); // 未読バッジ再計算のため（あなたの実装に合わせて再ロード）
  }

  // アバター＋未読バッジ
  Widget _avatarWithBadge(String url, int unread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [CircleAvatar(radius: 22, backgroundImage: NetworkImage(url))],
    );
  }

  // 右側に表示する未読チップ
  Widget _unreadChip(int unread) {
    if (unread <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.red.withOpacity(0.35)),
      ),
      child: Text(
        unread > 99 ? '99+' : '$unread',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    // 右側に時刻と並べたいなら Row で包むなど調整どうぞ
  }

  // ---------- 画面 ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット'),
        actions: [
          // 許可リストの確認・削除（リアルタイム）
          StreamBuilder<Set<String>>(
            stream: _streamAllowedSenders(),
            builder: (context, snap) {
              final allowed = snap.data ?? const <String>{};
              return PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                itemBuilder: (context) {
                  if (allowed.isEmpty) {
                    return const [
                      PopupMenuItem<String>(
                        value: '__none__',
                        enabled: false,
                        child: Text('許可済み送信元はありません'),
                      ),
                    ];
                  }
                  return allowed
                      .map(
                        (e) => PopupMenuItem<String>(
                          value: e,
                          child: Row(
                            children: [
                              const Icon(Icons.email, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e)),
                              IconButton(
                                tooltip: 'この送信元を削除',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => Navigator.pop(context, e),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList();
                },
                onSelected: (email) async {
                  if (email != '__none__') {
                    await _removeAllowedSender(email);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('削除しました: $email')));
                  }
                },
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<Set<String>>(
        stream: _streamAllowedSenders(),
        builder: (context, snap) {
          final allowed = snap.data ?? const <String>{};

          if (allowed.isEmpty) {
            return const Center(child: Text('右下の「＋」から表示したい送信元を追加してください'));
          }

          // メインの取得（スレッド最新まとめ）
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadChatsFor(allowed),
            builder: (context, fsnap) {
              if (fsnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (fsnap.hasError) {
                return Center(child: Text('Error: ${fsnap.error}'));
              }

              final chatsRaw = fsnap.data ?? const <Map<String, dynamic>>[];
              if (chatsRaw.isEmpty) {
                // 未読バッジも不要だが、allowed があるので一応未読だけチェックしても良い
                return const Center(child: Text('一致するスレッドがありません'));
              }

              // 送信元メール → 最新スレッド情報
              final senderToLatest = <String, Map<String, dynamic>>{};
              for (final m in chatsRaw) {
                final email = ((m['fromEmail'] ?? '') as String).toLowerCase();
                if (email.isNotEmpty) senderToLatest[email] = m;
              }

              // 未読数（送信元ごと）
              return FutureBuilder<Map<String, int>>(
                future: _loadUnreadCounts(allowed),
                builder: (context, usnap) {
                  final unreadMap = usnap.data ?? const <String, int>{};

                  // Map -> Chat モデル
                  final chatList = senderToLatest.values
                      .map(_mapToChat)
                      .toList();

                  return ListView.separated(
                    itemCount: chatList.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final chat = chatList[index];
                      final unread =
                          unreadMap[chat.senderEmail.toLowerCase()] ?? 0;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: cs.surfaceVariant,
                        leading: _avatarWithBadge(chat.avatarUrl, unread),
                        title: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              chat.time,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            _unreadChip(unread),
                          ],
                        ),
                        onTap: () {
                          if (chat.senderEmail.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonChatScreen(
                                senderEmail: chat.senderEmail,
                                title: chat.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSenderDialog,
        child: const Icon(Icons.add),
      ),
      backgroundColor: cs.surface,
    );
  }

  // Map -> Chat 表示モデル
  Chat _mapToChat(Map<String, dynamic> m) {
    final threadId = (m['threadId'] ?? m['id'] ?? '').toString();
    final name = (m['counterpart'] ?? m['from'] ?? '(unknown)').toString();
    final lastMessage = (m['lastMessage'] ?? m['snippet'] ?? '(No message)')
        .toString();
    final time = (m['time'] ?? '').toString();
    final senderEmail = (m['fromEmail'] ?? _extractEmail(name) ?? '')
        .toString();

    const avatar = 'https://placehold.jp/150x150.png';

    return Chat(
      threadId: threadId,
      name: name,
      lastMessage: lastMessage,
      time: time,
      avatarUrl: avatar,
      senderEmail: senderEmail,
    );
  }
}

// --- 表示モデル ---
class Chat {
  final String threadId;
  final String name;
  final String lastMessage;
  final String time;
  final String avatarUrl;
  final String senderEmail;

  Chat({
    required this.threadId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.avatarUrl,
    required this.senderEmail,
  });
}
