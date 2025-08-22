import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

final GoogleSignIn _gsi = GoogleSignIn(
  scopes: <String>['email', 'profile'],
);

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({Key? key}) : super(key: key);

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  User? _user;

  Future<void> _handleSignIn() async {
    try {
      final GoogleSignInAccount? account =
          await _gsi.signInSilently() ?? await _gsi.signIn();
      if (account == null) return;

      final GoogleSignInAuthentication googleAuth =
          await account.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() => _user = userCredential.user);
    } catch (e) {
      debugPrint("Sign-in error: $e");
    }
  }

  Future<void> _handleSignOut() async {
    await _gsi.signOut();
    await FirebaseAuth.instance.signOut();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Google Sign-In")),
      body: Center(
        child: _user == null
            ? ElevatedButton(
                onPressed: _handleSignIn,
                child: const Text("Sign in with Google"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Hello, ${_user!.displayName}"),
                  ElevatedButton(
                    onPressed: _handleSignOut,
                    child: const Text("Sign out"),
                  ),
                ],
              ),
      ),
    );
  }
}
