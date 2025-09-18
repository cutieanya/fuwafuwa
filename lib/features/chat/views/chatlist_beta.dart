// chat_beta_screen.dart
import 'package:flutter/material.dart';
import 'pull_down_reveal.dart';

class ChatBetaScreen extends StatelessWidget {
  const ChatBetaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PullDownReveal(
              minChildSize: 0.86,
              handle: false,
              backBar: const _AccountsBar(),
              frontBuilder: (scroll) {
                return CustomScrollView(
                  controller: scroll,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ヘッダー：左「Chat」右「Edit」(黒丸ボタン)
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                          child: Row(
                            children: [
                              const Text(
                                'Chat',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Tooltip(
                                message: 'Edit', // ★ 追加必須
                                child: InkWell(
                                  onTap: () {
                                    // TODO: 編集フローへ
                                  },
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 検索ボタン
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // TODO: 検索画面へ or 検索バー表示
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('Search'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE0E0E0)),
                              foregroundColor: Colors.black87,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // チャットリスト（builder ではなく delegate を使用）
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text('Chat $i'),
                          subtitle: const Text('Last message preview…'),
                          onTap: () {},
                        ),
                        childCount: 30,
                      ),
                    ),

                    // 下の入力バー等と重ならない余白
                    SliverToBoxAdapter(child: SizedBox(height: bottomPad + 72)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsBar extends StatelessWidget {
  const _AccountsBar({super.key, this.height = 240, this.iconRadius = 26});

  final double height;
  final double iconRadius;

  @override
  Widget build(BuildContext context) {
    final r = iconRadius; // ← 丸アイコン半径

    return Container(
      height: height,
      color: Colors.black,
      padding: const EdgeInsets.only(top: 4, left: 12, right: 12), // 上寄せ
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _round(r, const Icon(Icons.add, size: 24, color: Colors.black)),
              const SizedBox(width: 12),
              _round(
                r,
                const Text(
                  'All',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _round(
                r,
                const Icon(Icons.person, size: 24, color: Colors.black),
              ),
              const SizedBox(width: 12),
              _round(
                r,
                const Icon(
                  Icons.alternate_email,
                  size: 24,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              _round(r, const Icon(Icons.star, size: 24, color: Colors.black)),
              // ...追加
            ],
          ),
        ),
      ),
    );
  }

  Widget _round(double r, Widget child) {
    return Container(
      width: r * 2,
      height: r * 2,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
