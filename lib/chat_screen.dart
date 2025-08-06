import 'package:flutter/material.dart';

// 【推奨】チームを止めないための「機能的な」最低限
class ChatScreen extends StatelessWidget {
  // この「契約」部分がチーム開発では最重要
  final String threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    // 動作確認用の仮表示。ここはもりこさんが全部消してOK
    return Scaffold(
      appBar: AppBar(title: Text(threadId)),
    );
  }
}