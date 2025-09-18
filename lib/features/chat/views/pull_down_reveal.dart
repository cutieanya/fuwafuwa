import 'package:flutter/material.dart';

class PullDownReveal extends StatefulWidget {
  const PullDownReveal({
    super.key,
    required this.frontBuilder, // 白いパネルの中身
    required this.backBar, // 背景の黒いアイコンバー
    this.minChildSize = 0.86, // どれだけ引っ張ると見えるか（0〜1）
    this.handle = true, // つまみ(グラバー)を出すか
  });

  final Widget Function(ScrollController) frontBuilder;
  final Widget backBar;
  final double minChildSize;
  final bool handle;

  @override
  State<PullDownReveal> createState() => _PullDownRevealState();
}

class _PullDownRevealState extends State<PullDownReveal> {
  final _controller = DraggableScrollableController();
  double _radius = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final size = _controller.size; // 1.0(全画面) → minChildSize(引っ張り時)
      final t = ((1.0 - size) / (1.0 - widget.minChildSize)).clamp(0.0, 1.0);
      setState(() => _radius = 28 * t); // 引っ張るほど角丸が大きくなる
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背面：黒いバー（Googleアイコン等を並べる）
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: widget.backBar,
              ),
            ),
          ),
        ),

        // 前面：白いパネルをドラッグで下げる
        DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: 1.0,
          maxChildSize: 1.0,
          minChildSize: widget.minChildSize,
          expand: true,
          snap: true,
          snapSizes: const [1.0],
          builder: (context, scrollController) {
            return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: CustomScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (widget.handle) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: 64,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  // ここから先が「白いパネルの本体」
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: widget.frontBuilder(scrollController),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
