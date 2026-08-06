import 'package:flutter/material.dart';

import '../domain/draw.dart';
import 'ball.dart';
import 'format.dart';

/// ① 당첨번호 탭 (설계 문서 §8).
///
/// 앱을 열면 곧바로 최신 회차가 보인다. 로그인도 온보딩도 없다 —
/// 이게 이 앱의 경쟁력이라 첫 화면을 무겁게 만들지 않는다.
/// 좌우 스와이프로 과거 회차를 오간다.
class DrawTab extends StatefulWidget {
  const DrawTab({super.key, required this.draws});

  /// 회차 오름차순.
  final List<Draw> draws;

  @override
  State<DrawTab> createState() => _DrawTabState();
}

class _DrawTabState extends State<DrawTab> {
  // draws는 오름차순이지만 화면은 최신부터 보여준다.
  // 페이지 0 = 최신 회차이므로 왼쪽으로 밀면 과거로 간다.
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.draws.length,
      itemBuilder: (context, i) =>
          _DrawPage(draw: widget.draws[widget.draws.length - 1 - i]),
    );
  }
}

class _DrawPage extends StatelessWidget {
  const _DrawPage({required this.draw});

  final Draw draw;

  String get _dateText =>
      '${draw.date.year}.${draw.date.month.toString().padLeft(2, '0')}'
      '.${draw.date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${draw.round}회',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$_dateText 추첨', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 28),
          _Numbers(draw: draw),
          const SizedBox(height: 32),
          _Facts(draw: draw),
        ],
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.draw});

  final Draw draw;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...draw.numbers.map((n) => Ball(n)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text('+', style: TextStyle(fontSize: 20, color: Colors.grey)),
        ),
        Ball(draw.bonus),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.draw});

  final Draw draw;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('1등 당첨금', formatWon(draw.firstAmount)),
      ('1등 당첨자', '${draw.firstWinners}명'),
      ('총 판매금액', formatWon(draw.totalSales)),
      if (draw.winAuto + draw.winManual + draw.winSemi > 0)
        ('자동/수동/반자동', '${draw.winAuto} / ${draw.winManual} / ${draw.winSemi}'),
    ];

    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
