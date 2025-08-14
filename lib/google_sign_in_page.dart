import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Google Sign-In Test', home: SignInTest());
  }
}

class SignInTest extends StatefulWidget {
  const SignInTest({super.key});

  @override
  State<SignInTest> createState() => _SignInTestState();
}

class _SignInTestState extends State<SignInTest> {
  GoogleSignInAccount? _user;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    // Initialize and listen to authentication events
    await GoogleSignIn.instance.initialize();

    GoogleSignIn.instance.authenticationEvents.listen((event) {
      setState(() {
        _user = switch (event) {
          GoogleSignInAuthenticationEventSignIn() => event.user,
          GoogleSignInAuthenticationEventSignOut() => null,
        };
      });
    });
  }

  Future<void> _signIn() async {
    try {
      // Check if platform supports authenticate
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        await GoogleSignIn.instance.authenticate(scopeHint: ['email']);
      } else {
        // Handle web platform differently
        print('This platform requires platform-specific sign-in UI');
      }
    } catch (e) {
      print('Sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Sign-In Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_user != null)
              Text('Signed in: ${_user!.displayName}')
            else
              ElevatedButton(
                onPressed: _signIn,
                child: Text('Sign in with Google'),
              ),
          ],
        ),
      ),
    );
  }
}
