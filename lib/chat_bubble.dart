import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final DateTime time;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: EdgeInsets.only(
                left: isMe ? 50 : 10,
                right: isMe ? 10 : 50,
              ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,),
              decoration: BoxDecoration(
                color: isMe ? Colors.lightBlue.shade300 : Colors.grey.shade300,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                  isMe ? const Radius.circular(18) : const Radius.circular(0),
                  bottomRight:
                  isMe ? const Radius.circular(0) : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: isMe ? 0 : null,
              left: isMe ? null : 0,
              child: CustomPaint(
                size: const Size(12, 12),
                painter: BubbleTailPainter(isMe: isMe),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
class BubbleTailPainter extends CustomPainter {
  final bool isMe;
  BubbleTailPainter({required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMe ? Colors.lightBlueAccent : Colors.grey.shade300
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isMe) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, size.height);

    } else {
      path.moveTo(0,size.width);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}