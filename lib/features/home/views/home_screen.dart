// home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// =======================
///  モデル
/// =======================
class _LinkedAccount {
  final String email;
  final String displayName;
  final String photoUrl;
  const _LinkedAccount({
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });
}

/// =======================
///  画面本体
/// =======================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Firestore: users/{uid}/prefs/filters & accounts
  DocumentReference<Map<String, dynamic>> get _filtersDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('未ログインです。ログイン後にお試しください。');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('filters');
  }

  DocumentReference<Map<String, dynamic>> get _accountsDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('未ログインです。ログイン後にお試しください。');
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('prefs')
        .doc('accounts');
  }

  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  // 選択中アカウント（null=All）
  String? _activeAccountEmail;

  // 編集UI
  bool _isEditingDockOpen = false;
  bool _isDeleteMode = false;
  final Set<String> _selectedForDelete = {};

  // 追加用TextField
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  /// ----------------- Firestore Streams -----------------
  Stream<List<_LinkedAccount>> _streamLinkedAccounts() {
    return _accountsDoc.snapshots().map((snap) {
      final raw = (snap.data()?['linked'] as List?) ?? const [];
      return raw
          .map((e) {
            final m = (e as Map).cast<String, dynamic>();
            return _LinkedAccount(
              email: (m['email'] ?? '').toString().toLowerCase(),
              displayName: (m['displayName'] ?? '').toString(),
              photoUrl: (m['photoUrl'] ?? '').toString(),
            );
          })
          .where((a) => a.email.isNotEmpty)
          .toList();
    });
  }

  Stream<List<String>> _streamAllowedSenders() {
    return _filtersDoc.snapshots().map((snap) {
      final list =
          (snap.data()?['allowedSenders'] as List?)?.cast<String>() ??
          const <String>[];
      return list.map((e) => e.toLowerCase()).toList();
    });
  }

  /// ----------------- Add / Remove emails -----------------
  String? _extractEmail(String raw) {
    final m = RegExp(
      r'([a-zA-Z0-9_.+\-]+@[a-zA-Z0-9\-.]+\.[a-zA-Z]{2,})',
    ).firstMatch(raw);
    return m?.group(1)?.toLowerCase();
  }

  Future<void> _addAllowedSender(String raw) async {
    final email = _extractEmail(raw.trim());
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

  Future<void> _removeSelectedSenders() async {
    if (_selectedForDelete.isEmpty) return;
    await _filtersDoc.set({
      'allowedSenders': FieldValue.arrayRemove(
        _selectedForDelete.map((e) => e.toLowerCase()).toList(),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _selectedForDelete.clear();
  }

  /// ----------------- Link Google Account -----------------
  Future<void> _linkGoogleAccount() async {
    try {
      final account = await _gsi.signIn();
      if (account == null) return; // キャンセル
      await _accountsDoc.set({
        'linked': FieldValue.arrayUnion([
          {
            'email': account.email.toLowerCase(),
            'displayName': account.displayName,
            'photoUrl': account.photoUrl,
            'linkedAt': FieldValue.serverTimestamp(),
          },
        ]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('アカウントを追加しました：${account.email}')));
      // 初回は選択状態にしてもOK
      setState(() {
        _activeAccountEmail ??= account.email.toLowerCase();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('追加に失敗: $e')));
    }
  }

  /// 現在のFirebaseAuthユーザーを先頭に表示
  _LinkedAccount? _currentUserAsLinked() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || (u.email ?? '').isEmpty) return null;
    return _LinkedAccount(
      email: (u.email ?? '').toLowerCase(),
      displayName: u.displayName ?? '',
      photoUrl: u.photoURL ?? '',
    );
  }

  /// ----------------- Simple bottom sheet base -----------------
  /// タイトル・本文・左右ボタンを黒白で統一した下からのシート
  Future<T?> _showSimpleSheet<T>({required Widget content}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: content,
      ),
    );
  }

  ButtonStyle get _filledBlack => FilledButton.styleFrom(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  ButtonStyle get _outlinedBlack => OutlinedButton.styleFrom(
    foregroundColor: Colors.black,
    side: const BorderSide(color: Colors.black, width: 1),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  /// ----------------- Add Sheet (連続追加：黒白統一) -----------------
  Future<void> _openAddSheet() async {
    _addController.clear();
    await _showSimpleSheet<void>(
      content: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'メールアドレスを追加',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'example@gmail.com',
                hintStyle: const TextStyle(color: Colors.black54),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (v) async {
                if (v.trim().isEmpty) return;
                await _addAllowedSender(v);
                _addController.clear(); // 連続追加OK
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _outlinedBlack,
                    onPressed: () async {
                      final v = _addController.text;
                      if (v.trim().isEmpty) return;
                      await _addAllowedSender(v);
                      _addController.clear(); // 連続追加OK
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: _filledBlack,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完了'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ----------------- Delete Confirm Sheet（黒白統一） -----------------
  Future<bool> _openDeleteConfirmSheet(int count) async {
    final result = await _showSimpleSheet<bool>(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '削除しますか？',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('$count 件のメールアドレスを削除します。', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _outlinedBlack,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('キャンセル'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: _filledBlack,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('削除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result == true;
  }

  /// ----------------- UI: 上のアカウントバー -----------------
  Widget _accountsBar() {
    final current = _currentUserAsLinked();
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Linked Accounts',
              style: TextStyle(
                fontSize: 24, // サイズ指定
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<_LinkedAccount>>(
              stream: _streamLinkedAccounts(),
              builder: (context, snapshot) {
                // 先頭に現在ログイン中を重複回避して挿入
                final fromDb = snapshot.data ?? const <_LinkedAccount>[];
                final accounts = <_LinkedAccount>[
                  if (current != null &&
                      !fromDb.any(
                        (a) =>
                            a.email.toLowerCase() ==
                            current.email.toLowerCase(),
                      ))
                    current,
                  ...fromDb,
                ];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _AllCircle(
                        selected: _activeAccountEmail == null,
                        onTap: () => setState(() => _activeAccountEmail = null),
                      ),
                      const SizedBox(width: 12),
                      ...accounts.map((a) {
                        final isSel =
                            _activeAccountEmail != null &&
                            a.email.toLowerCase() ==
                                _activeAccountEmail!.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _AccountCircle(
                            account: a,
                            selected: isSel,
                            onTap: () => setState(() {
                              _activeAccountEmail = a.email;
                            }),
                          ),
                        );
                      }),
                      _AddCircle(onTap: _linkGoogleAccount),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ----------------- UI: メール一覧カード（白角丸：上左右＋右下） -----------------
  Widget _mailListCard() {
    return Expanded(
      child: Padding(
        // 横いっぱいにしたいので左右の余白は 0
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        child: Container(
          width: double.infinity, // 念のため横幅いっぱい指定
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(0), // 左下のみ直角
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withOpacity(0.15),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias, // 角丸に沿って内部もクリップ
          child: StreamBuilder<List<String>>(
            stream: _streamAllowedSenders(),
            builder: (context, snap) {
              final senders = (snap.data ?? const <String>[])
                  .map((e) => e.toLowerCase())
                  .toList();

              if (senders.isEmpty) {
                return const Center(child: Text('メールアドレスを追加してください'));
              }

              final list = senders;

              return ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFECECEC)),
                itemBuilder: (context, i) {
                  final email = list[i];
                  final selected = _selectedForDelete.contains(email);
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.mail, color: Colors.black87),
                    ),
                    title: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _isDeleteMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedForDelete.add(email);
                                } else {
                                  _selectedForDelete.remove(email);
                                }
                              });
                            },
                          )
                        : null,
                    onTap: _isDeleteMode
                        ? () {
                            setState(() {
                              if (selected) {
                                _selectedForDelete.remove(email);
                              } else {
                                _selectedForDelete.add(email);
                              }
                            });
                          }
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// ----------------- 編集ドック（＋／−／完了） -----------------
  Widget _editDock() {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white, // ドックは白
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 追加
            IconButton(
              tooltip: 'メールを追加',
              onPressed: _openAddSheet,
              icon: const Icon(Icons.add, color: Colors.black),
            ),
            // 削除モード トグル
            IconButton(
              tooltip: _isDeleteMode ? '削除モード解除' : '削除モード',
              onPressed: () => setState(() {
                _isDeleteMode = !_isDeleteMode;
                if (!_isDeleteMode) _selectedForDelete.clear();
              }),
              icon: Icon(
                Icons.remove,
                color: _isDeleteMode ? Colors.red : Colors.black,
              ),
            ),
            // 完了
            FilledButton(
              style: _filledBlack,
              onPressed: () async {
                if (_isDeleteMode && _selectedForDelete.isNotEmpty) {
                  final ok = await _openDeleteConfirmSheet(
                    _selectedForDelete.length,
                  );
                  if (ok) {
                    await _removeSelectedSenders();
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('削除しました')));
                  }
                }
                // ドックを閉じて、削除モードも解除
                setState(() {
                  _isEditingDockOpen = false;
                  _isDeleteMode = false;
                  _selectedForDelete.clear();
                });
              },
              child: const Text('完了'),
            ),
          ],
        ),
      ),
    );
  }

  /// ----------------- FAB（鉛筆 / 編集ドック切替） -----------------
  Widget _fab() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: _isEditingDockOpen
          ? _editDock()
          : FloatingActionButton(
              key: const ValueKey('fab-pencil'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              onPressed: () => setState(() => _isEditingDockOpen = true),
              child: const Icon(Icons.edit),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 全体の背景は黒
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上：アカウントバー（常時表示）
            _accountsBar(),
            // 下：白い角丸カードにメール一覧
            _mailListCard(),
          ],
        ),
      ),
      floatingActionButton: _fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// =======================
///  サブウィジェット（アカウント丸）
/// =======================
class _AllCircle extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _AllCircle({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white : Colors.black;
    final fg = selected ? Colors.black : Colors.white;
    final border = selected ? Colors.white : Colors.white54;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          'All',
          style: TextStyle(color: fg, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AccountCircle extends StatelessWidget {
  final _LinkedAccount account;
  final bool selected;
  final VoidCallback onTap;
  const _AccountCircle({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? Colors.white : Colors.white54;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: CircleAvatar(
          radius: 24,
          backgroundImage: (account.photoUrl.isNotEmpty)
              ? NetworkImage(account.photoUrl)
              : null,
          backgroundColor: Colors.white10,
          child: (account.photoUrl.isEmpty)
              ? Text(
                  account.email.isNotEmpty
                      ? account.email[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _AddCircle extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(left: 4),
        decoration: const ShapeDecoration(
          color: Colors.black,
          shape: CircleBorder(),
        ),
        child: const Icon(Icons.add_circle, color: Colors.white, size: 48),
      ),
    );
  }
}
