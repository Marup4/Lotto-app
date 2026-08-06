import 'package:flutter/material.dart';

import '../domain/draw.dart';

/// 번호 볼. 색상 구간은 설계 문서 §7 F1을 따른다.
class Ball extends StatelessWidget {
  const Ball(this.number, {super.key, this.size = 44});

  final int number;
  final double size;

  static const _colors = {
    BallGroup.yellow: Color(0xFFFBC400),
    BallGroup.blue: Color(0xFF69C8F2),
    BallGroup.red: Color(0xFFFF7272),
    BallGroup.grey: Color(0xFFAAAAAA),
    BallGroup.green: Color(0xFFB0D840),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colors[ballGroup(number)],
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
