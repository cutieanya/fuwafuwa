import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // flutterfire configure で生成されるファイル

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
  GoogleSignInAccount? _user;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    await GoogleSignIn.instance.initialize();
    _authSub = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        _user = switch (event) {
          GoogleSignInAuthenticationEventSignIn() => event.user,
          GoogleSignInAuthenticationEventSignOut() => null,
        };
      });
    });
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        // Google 側にサインイン
        final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
            .authenticate(scopeHint: ['email']);
        if (googleUser == null) {
          if (!mounted) return;
          setState(() {
            _message = 'キャンセルされました';
          });
          return;
        }

        // Google のトークンを取得
        final googleAuth = await googleUser.authentication;

        // FirebaseAuth 用の credential に変換してサインイン
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);

        if (!mounted) return;
        final u = FirebaseAuth.instance.currentUser;
        setState(() {
          _message = 'サインイン成功：${u?.displayName ?? u?.email ?? "No name"}';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _message = 'このプラットフォームは別UIでのサインインが必要です';
        });
      }
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
      await GoogleSignIn.instance.signOut();
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
  void dispose() {
    _authSub?.cancel(); // 購読解除
    super.dispose();
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
