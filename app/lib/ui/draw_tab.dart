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
  int _page = 0;

  /// 페이지 인덱스 → 회차 (0이 최신).
  Draw _drawAt(int page) => widget.draws[widget.draws.length - 1 - page];

  /// 회차 → 페이지 인덱스.
  int _pageOf(int round) =>
      widget.draws.length - 1 - widget.draws.indexWhere((d) => d.round == round);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int round) {
    // 멀리 떨어진 회차로 애니메이션하면 중간 페이지가 전부 스쳐 지나가
    // 느리고 산만하다. 곧바로 이동한다.
    _controller.jumpToPage(_pageOf(round));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoundPicker(
          draws: widget.draws,
          selected: _drawAt(_page).round,
          onSelected: _jumpTo,
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.draws.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _DrawPage(draw: _drawAt(i)),
          ),
        ),
      ],
    );
  }
}

/// 회차 선택기 (설계 문서 §7 F1).
///
/// 스와이프만으로는 과거 회차에 닿기까지 너무 많이 넘겨야 한다.
/// 화면 제목을 겸하므로 크게 쓴다 — 눌러서 바꿀 수 있다는 것도 함께 드러난다.
/// 최신 회차가 위로 오도록 역순으로 나열한다.
class _RoundPicker extends StatelessWidget {
  const _RoundPicker({
    required this.draws,
    required this.selected,
    required this.onSelected,
  });

  final List<Draw> draws;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .headlineMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DropdownButton<int>(
          value: selected,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(12),
          iconSize: 30,
          style: titleStyle,
          // 펼쳐진 목록은 촘촘해야 여러 회차가 한눈에 들어온다.
          selectedItemBuilder: (context) => [
            for (final d in draws.reversed)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${d.round}회', style: titleStyle),
              ),
          ],
          items: [
            for (final d in draws.reversed)
              DropdownMenuItem(
                value: d.round,
                child: Text('${d.round}회',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
          ],
          onChanged: (round) {
            if (round != null) onSelected(round);
          },
        ),
      ),
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
          // 회차 번호는 선택기가 겸한다 (중복 표기 방지).
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
    // 추첨 직후에는 당첨번호만 나오고 집계는 나중에 채워진다.
    // 그때 "0원"을 보여주면 사실과 다르다.
    final rows = draw.isSettled
        ? <(String, String)>[
            ('1등 당첨금', formatWon(draw.firstAmount)),
            ('1등 당첨자', '${draw.firstWinners}명'),
            ('총 판매금액', formatWon(draw.totalSales)),
            if (draw.winAuto + draw.winManual + draw.winSemi > 0)
              (
                '자동/수동/반자동',
                '${draw.winAuto} / ${draw.winManual} / ${draw.winSemi}'
              ),
          ]
        : const <(String, String)>[
            ('1등 당첨금', '집계 중'),
            ('1등 당첨자', '집계 중'),
            ('총 판매금액', '집계 중'),
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
