import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          TextField(),
          TextField(),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("ログイン"),
          ),
        ],
      ),
    );
  }
}
