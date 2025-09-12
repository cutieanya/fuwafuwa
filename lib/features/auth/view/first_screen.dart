// lib/firstscreen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ← プロジェクト構成に合わせて調整してください
import 'package:fuwafuwa/features/auth/view/lobby_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 左下など任意位置に“丸い発光”を置き、色を循環させる背景ウィジェット
class BlurredColorCyclingBlob extends StatefulWidget {
  const BlurredColorCyclingBlob({
    super.key,
    this.size = 2500, // 丸の直径
    this.alignment = Alignment.bottomLeft, // 配置
    this.offset = const Offset(-80, 40), // 微調整（+x=右 / +y=下）
    this.opacity = 1.0, // 透明度
    this.blurSigma = 40, // ぼかしの強さ
    this.colors = const [
      ui.Color.fromARGB(255, 189, 35, 24), // Red
      ui.Color.fromARGB(255, 253, 232, 38), // Yellow
      ui.Color.fromARGB(255, 16, 125, 20), // Green
      ui.Color.fromARGB(255, 20, 23, 187), // Blue
    ],
    this.duration = const Duration(seconds: 16), // 一周の時間
  });

  final double size;
  final Alignment alignment;
  final Offset offset;
  final double opacity;
  final double blurSigma;
  final List<Color> colors;
  final Duration duration;

  @override
  State<BlurredColorCyclingBlob> createState() =>
      _BlurredColorCyclingBlobState();
}

class _BlurredColorCyclingBlobState extends State<BlurredColorCyclingBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    final seq = <TweenSequenceItem<Color?>>[];
    for (var i = 0; i < widget.colors.length; i++) {
      final a = widget.colors[i];
      final b = widget.colors[(i + 1) % widget.colors.length];
      seq.add(
        TweenSequenceItem(
          tween: ColorTween(begin: a, end: b),
          weight: 1,
        ),
      );
    }
    _color = TweenSequence(
      seq,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _color,
          builder: (_, __) {
            final c = _color.value ?? widget.colors.first;
            return Align(
              alignment: widget.alignment,
              child: Transform.translate(
                offset: widget.offset,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Opacity(
                    opacity: widget.opacity,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: widget.blurSigma,
                        sigmaY: widget.blurSigma,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.withOpacity(1),
                              c.withOpacity(1),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 画像（spring.png など）を角に“ぼかして”置く小コンポーネント
class BlurredCornerImage extends StatelessWidget {
  const BlurredCornerImage({
    super.key,
    required this.asset,
    this.size = 420,
    this.alignment = Alignment.topRight, // 右上
    this.offset = const Offset(30, 10), // 少し内側＆下へ
    this.opacity = 0.85,
    this.blurSigma = 30,
    this.angle = 0.0, // 必要なら回転（rad）
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final Alignment alignment;
  final Offset offset;
  final double opacity;
  final double blurSigma;
  final double angle;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: offset,
          child: SizedBox(
            width: size,
            height: size,
            child: Opacity(
              opacity: opacity,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment.center,
                  child: Image.asset(
                    asset,
                    fit: fit,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **1画面完結版**：この画面の左下ボタンで Google サインイン → 成功したら LobbyPage へ
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _gsi = GoogleSignIn(scopes: const ['email']);
  bool _loading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final account = await _gsi.signIn();
      if (account == null) return; // キャンセル
      final tokens = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);

      if (!mounted) return;
      // 成功 → チャット（ロビー）へ
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LobbyPage()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-in error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景グラデ
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7F8FA), Color(0xFFEFF1F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // 左下：色がゆっくり循環する“発光の丸”
          const Positioned.fill(
            child: BlurredColorCyclingBlob(
              size: 400,
              alignment: Alignment.bottomLeft,
              offset: Offset(-70, 80),
              blurSigma: 100,
              opacity: 0.9,
            ),
          ),
          // 右上：ぼかし画像（spring.png）
          const Positioned.fill(
            child: BlurredCornerImage(
              asset: 'assets/images/spring.png',
              size: 800,
              alignment: Alignment.topRight,
              offset: Offset(120, -80),
              blurSigma: 20,
              opacity: 0.9,
            ),
          ),

          Positioned(
            left: 24,
            top: 24,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 32), // ← ここで「少し下げる」
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform(
                      alignment: Alignment.topLeft,
                      transform: Matrix4.diagonal3Values(
                        1.0,
                        1.0,
                        1.0,
                      ), // X=1.0, Y=1.08, Z=1.0
                      child: Stack(
                        children: [
                          // 1) 縁取り
                          Text(
                            'THREAGLY',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 56,
                              letterSpacing: 0,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3.0
                                ..color = Colors.black,
                            ),
                          ),
                          // 2) 塗り
                          const Text(
                            'THREAGLY',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Improve your life',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'Manage mail',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 左下：黒い「Sign in」ボタン（Googleアイコン付き）
          Positioned(
            left: 40,
            bottom: 60,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _handleGoogleSignIn,
                icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                label: const Text('Sign in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // 黒ボタン
                  foregroundColor: Colors.white, // 白文字
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(), // ピル型
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 24,
                  ),
                  elevation: 6,
                ),
              ),
            ),
          ),

          // ローディング中の簡易オーバーレイ
          if (_loading)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withOpacity(0.08),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
