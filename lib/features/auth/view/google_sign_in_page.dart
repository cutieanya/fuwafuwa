import 'dart:async';
import 'package:flutter/material.dart';

// ▼ v5方式で使うGoogle Sign-In
import 'package:google_sign_in/google_sign_in.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../firebase_options.dart'; // flutterfire configure で生成

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'Google Sign-In Test', home: SignInTest());
  }
}

class SignInTest extends StatefulWidget {
  const SignInTest({super.key});
  @override
  State<SignInTest> createState() => _SignInTestState();
}

class _SignInTestState extends State<SignInTest> {
  // ==============================================================
  // v5 方式：自前のインスタンスを持つ（← v6 の GoogleSignIn.instance ではない）
  // Gmail を読むための scope をここで宣言しておく（後でGmail APIで利用）
  // ==============================================================
  final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly', // Gmail読み取り
    ],
  );

  bool _loading = false;
  String? _message;

  // v6の initialize() / authenticationEvents は不要（v5では存在しないため）

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      // ==========================================================
      // v5 のサインイン：ここでGoogle側のUIが出る
      // 成功すると GoogleSignInAccount が返る（nullならキャンセル）
      // ==========================================================
      final GoogleSignInAccount? googleUser = await _gsi.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _message = 'キャンセルされました');
        return;
      }

      // ==========================================================
      // v5 では Google の OAuth トークンがここで取れる
      // ・idToken：Firebase Auth 連携に使用
      // ・accessToken：Gmail REST API への Bearer に使用（後でgmail_service.dartで使う）
      // ==========================================================
      final googleAuth = await googleUser.authentication;

      // FirebaseAuth 用の credential に変換してログイン
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken, // ★ v5 でのみ取得可
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      final u = FirebaseAuth.instance.currentUser;
      setState(() {
        _message = 'サインイン成功：${u?.displayName ?? u?.email ?? "No name"}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Sign-in error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signOut();
      await _gsi.signOut(); // v5 のサインアウト
      if (!mounted) return;
      setState(() {
        _message = 'サインアウトしました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Sign-out error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sign-In Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) const CircularProgressIndicator(),
              if (!_loading && firebaseUser == null)
                ElevatedButton(
                  onPressed: _signIn,
                  child: const Text('Sign in with Google'),
                ),
              if (!_loading && firebaseUser != null)
                Column(
                  children: [
                    Text(
                      '現在のユーザー: ${firebaseUser.displayName ?? firebaseUser.email ?? "No name"}',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      ),
    );
  }
} 