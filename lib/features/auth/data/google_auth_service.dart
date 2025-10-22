// lib/features/auth/data/google_auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _gsi = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final GoogleSignIn _gsi;

  Future<UserCredential?> signInWithGoogle() async {
    final account = await _gsi.signIn();
    if (account == null) return null; // キャンセル
    final tokens = await account.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    return FirebaseAuth.instance.signInWithCredential(cred);
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _gsi.signOut();
  }
}
