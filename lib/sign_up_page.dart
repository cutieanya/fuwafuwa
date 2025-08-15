import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String email = "";
  String password = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(hintText: "メールアドレス"),
            onChanged: (value) {
              email = value;
            },
          ),
          TextField(
            decoration: const InputDecoration(hintText: "パスワード"),
            onChanged: (value) {
              password = value;
            },
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: () async {
              // firebase authで新規登録
              try {
                final credential = await FirebaseAuth.instance
                    .createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );
                Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                if (e.code == 'weak-password') {
                  print('The password provided is too weak.');
                } else if (e.code == 'email-already-in-use') {
                  print('The account already exists for that email.');
                }
              } catch (e) {
                print(e);
              }
            },
            child: const Text("登録"),
          ),
        ],
      ),
    );
  }
}
