import 'package:flutter/material.dart';

/// 통계·추천 화면에 고정 노출하는 안내 (설계 문서 §7 F3·§12).
///
/// "예측", "확률이 높다" 같은 표현을 쓰지 않는다는 원칙의 짝이다.
/// 사실 서술만 보여주는 것으로는 부족하고, 통계와 당첨 확률이 무관하다는
/// 것을 명시해야 한다. 심사 대응이자 정직성 문제다.
class Disclaimer extends StatelessWidget {
  const Disclaimer(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }
}
