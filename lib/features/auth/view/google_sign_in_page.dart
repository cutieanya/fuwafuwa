// lib/features/auth/view/google_sign_in_page.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});
  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      // 'https://www.googleapis.com/auth/gmail.readonly', // Gmailも読むなら追加
    ],
  );

  bool _loading = false;
  String? _message;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final account = await _gsi.signIn();
      if (account == null) {
        setState(() => _message = 'キャンセルされました');
        return;
      }
      final tokens = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);

      final u = FirebaseAuth.instance.currentUser;
      setState(() {
        _message = 'サインイン成功：${u?.displayName ?? u?.email ?? "No name"}';
      });
    } catch (e) {
      setState(() {
        _message = 'Sign-in error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
    });
    try {
      await FirebaseAuth.instance.signOut();
      await _gsi.signOut();
      setState(() {
        _message = 'サインアウトしました';
      });
    } catch (e) {
      setState(() {
        _message = 'Sign-out error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sign-In')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) const CircularProgressIndicator(),
              if (!_loading && user == null)
                SizedBox(
                  width: 260,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.g_translate),
                    label: const Text('Continue with Google'),
                    onPressed: _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (!_loading && user != null) ...[
                Text('現在のユーザー: ${user.displayName ?? user.email ?? "No name"}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ],
              const SizedBox(height: 12),
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      ),
    );
  }
}
