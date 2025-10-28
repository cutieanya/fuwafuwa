import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _processing = false;

  Future<void> _signOut() async {
    setState(() => _processing = true);
    try {
      // Firebase + Googleの両方をサインアウト（Google連携していなくてもOK）
      await FirebaseAuth.instance.signOut();
      final google = GoogleSignIn();
      if (await google.isSignedIn()) {
        await google.signOut();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed out')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Guest';
    final email = user?.email ?? 'no-email';
    final photoUrl = user?.photoURL;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 白黒ベース配色
    final bg = isDark ? Colors.black : Colors.white;
    final fg = isDark ? Colors.white : Colors.black;
    final subFg = isDark ? Colors.white70 : Colors.black54;
    final cardBg = isDark ? const Color(0xFF111111) : const Color(0xFFF8F8F8);
    final divider = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: fg),
      ),
      body: CustomScrollView(
        slivers: [
          // ヘッダー（アイコン・名前・メール）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  _Avatar(photoUrl: photoUrl, fallbackText: name),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(email, style: TextStyle(color: subFg)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ステータス・ミニカード（必要なら値を差し替えてね）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  _MiniStatCard(
                    label: 'Threads',
                    value: '12',
                    bg: cardBg,
                    fg: fg,
                    subFg: subFg,
                  ),
                  const SizedBox(width: 12),
                  _MiniStatCard(
                    label: 'Contacts',
                    value: '31',
                    bg: cardBg,
                    fg: fg,
                    subFg: subFg,
                  ),
                  const SizedBox(width: 12),
                  _MiniStatCard(
                    label: 'Unread',
                    value: '5',
                    bg: cardBg,
                    fg: fg,
                    subFg: subFg,
                  ),
                ],
              ),
            ),
          ),

          // セクション：アカウント
          _SectionHeader(title: 'ACCOUNT', fg: subFg),
          SliverToBoxAdapter(
            child: _CardGroup(
              cardBg: cardBg,
              divider: divider,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.alternate_email, color: fg),
                  title: Text(
                    'Switch Google Account',
                    style: TextStyle(color: fg),
                  ),
                  subtitle: Text(
                    'Sign in with another account',
                    style: TextStyle(color: subFg),
                  ),
                  onTap: () async {
                    // ここは「Googleアカウント切替」用の導線（アプリの仕様に合わせて処理追加）
                    final google = GoogleSignIn(scopes: ['email']);
                    try {
                      await google.signOut();
                      await google.signIn();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Switched account')),
                        );
                      }
                      setState(() {}); // UI更新
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switch failed: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.edit_outlined, color: fg),
                  title: Text('Edit Profile', style: TextStyle(color: fg)),
                  subtitle: Text('Name, photo', style: TextStyle(color: subFg)),
                  onTap: () {
                    // 今後の編集画面ができたらNavigator.pushで遷移
                    showDialog(
                      context: context,
                      builder: (_) => _SimpleDialog(
                        fg: fg,
                        bg: bg,
                        child: const Text('Coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // セクション：アプリ設定
          _SectionHeader(title: 'APP', fg: subFg),
          SliverToBoxAdapter(
            child: _CardGroup(
              cardBg: cardBg,
              divider: divider,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.dark_mode_outlined, color: fg),
                  title: Text('Appearance', style: TextStyle(color: fg)),
                  subtitle: Text(
                    'System default',
                    style: TextStyle(color: subFg),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _SimpleDialog(
                        fg: fg,
                        bg: bg,
                        child: const Text(
                          'Theme follows system.\n(If you add a theme toggle, wire it here.)',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.notifications_none, color: fg),
                  title: Text('Notifications', style: TextStyle(color: fg)),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _SimpleDialog(
                        fg: fg,
                        bg: bg,
                        child: const Text(
                          'Notification preferences — coming soon',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.lock_outline, color: fg),
                  title: Text(
                    'Privacy & Security',
                    style: TextStyle(color: fg),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _SimpleDialog(
                        fg: fg,
                        bg: bg,
                        child: const Text('Privacy settings — coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // サインアウト
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: divider),
                    foregroundColor: fg,
                  ),
                  onPressed: _processing ? null : _signOut,
                  child: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign out'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.fallbackText});
  final String? photoUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ring = isDark ? Colors.white12 : Colors.black12;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring),
          ),
        ),
        CircleAvatar(
          radius: 28,
          backgroundColor: isDark ? Colors.white10 : Colors.black12,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  _initials(fallbackText),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'G';
    if (parts.length == 1)
      return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.subFg,
  });

  final String label;
  final String value;
  final Color bg;
  final Color fg;
  final Color subFg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: subFg, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.fg});
  final String title;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(
          title,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({
    required this.children,
    required this.cardBg,
    required this.divider,
  });
  final List<Widget> children;
  final Color cardBg;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: _withDividers(children, divider)),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> tiles, Color divider) {
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i != tiles.length - 1) {
        out.add(Divider(height: 1, color: divider, thickness: 1));
      }
    }
    return out;
  }
}

class _SimpleDialog extends StatelessWidget {
  const _SimpleDialog({
    required this.child,
    required this.fg,
    required this.bg,
  });
  final Widget child;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg, fontSize: 14),
          child: child,
        ),
      ),
    );
  }
}
