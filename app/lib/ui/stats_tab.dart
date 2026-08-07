import 'package:flutter/material.dart';

import '../domain/draw.dart';
import '../domain/statistics.dart';
import 'ball.dart';
import 'disclaimer.dart';

/// ④ 통계 탭 (설계 문서 §8).
///
/// ⚠️ 재미 요소다. 지난 결과를 세어 보여줄 뿐 다음 회차와는 무관하다.
/// 문구는 전부 사실 서술이고, 하단 안내를 고정 노출한다.
///
/// 전체 누적 출현 빈도는 넣지 않는다. 1235회를 누적하면 45개 번호가 전부
/// 평균 근처로 수렴해 화면에서 아무 차이도 보이지 않는다 (2026-08-07 결정).
class StatsTab extends StatefulWidget {
  const StatsTab({super.key, required this.draws});

  /// 회차 오름차순.
  final List<Draw> draws;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  /// 빈도를 셀 구간. 보유 회차(100)를 넘지 않는 선에서 고른다.
  static const _windows = [10, 30, 50];
  int _window = 30;

  @override
  Widget build(BuildContext context) {
    final rounds = widget.draws.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _FrequencySection(
          draws: widget.draws,
          window: _window,
          windows: _windows,
          onWindowChanged: (w) => setState(() => _window = w),
        ),
        const SizedBox(height: 32),
        _DroughtSection(draws: widget.draws),
        const SizedBox(height: 32),
        _MethodSection(draws: widget.draws, rounds: rounds),
        const SizedBox(height: 28),
        const Disclaimer(
          '위 수치는 지금까지의 추첨 결과를 세어 보여주는 것입니다. '
          '다음 추첨 결과와는 아무런 관계가 없으며, 모든 번호의 당첨 확률은 같습니다.',
        ),
      ],
    );
  }
}

/// 최근 N회차 출현 빈도.
///
/// 한 번도 안 나온 번호는 목록에서 빼고 개수만 알린다 — 10회 구간에서는
/// 45개 중 절반 넘게 0이라, 다 그리면 0인 줄만 잔뜩 남는다.
/// 그 번호들은 어차피 아래 미출현 항목이 다룬다.
class _FrequencySection extends StatelessWidget {
  const _FrequencySection({
    required this.draws,
    required this.window,
    required this.windows,
    required this.onWindowChanged,
  });

  final List<Draw> draws;
  final int window;
  final List<int> windows;
  final ValueChanged<int> onWindowChanged;

  @override
  Widget build(BuildContext context) {
    final counts = frequency(draws, recent: window);
    final shown = [
      for (final e in counts.entries)
        if (e.value > 0) e
    ]..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final max = shown.isEmpty ? 1 : shown.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('많이 나온 번호'),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: [
            for (final w in windows)
              ButtonSegment(value: w, label: Text('최근 $w회')),
          ],
          selected: {window},
          onSelectionChanged: (s) => onWindowChanged(s.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 16),
        for (final e in shown)
          _BarRow(number: e.key, value: e.value, max: max, suffix: '${e.value}회'),
        const SizedBox(height: 8),
        Text('최근 $window회차에 나오지 않은 번호 ${45 - shown.length}개',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
    );
  }
}

/// 오래 안 나온 번호 TOP 10.
class _DroughtSection extends StatelessWidget {
  const _DroughtSection({required this.draws});

  final List<Draw> draws;

  @override
  Widget build(BuildContext context) {
    final top = droughts(draws, limit: 10);
    final max = top.isEmpty ? 1 : top.first.gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('오래 안 나온 번호'),
        const SizedBox(height: 4),
        Text('마지막으로 나온 뒤 지난 회차 수입니다.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        for (final d in top)
          _BarRow(
            number: d.number,
            value: d.gap,
            max: max,
            suffix: '${d.gap}회차',
          ),
      ],
    );
  }
}

/// 1등 당첨의 자동/수동/반자동 비율.
class _MethodSection extends StatelessWidget {
  const _MethodSection({required this.draws, required this.rounds});

  final List<Draw> draws;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final m = methodTotals(draws);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('1등은 어떻게 샀을까'),
        const SizedBox(height: 4),
        Text('최근 $rounds회차 1등 ${m.total}건 기준입니다.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        // 261회차 이하만 있으면 구분 자료가 없어 합이 0이다. 0으로 나누지 않는다.
        if (m.total == 0)
          Text('이 구간에는 구매 방식 자료가 없습니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600))
        else ...[
          for (final (label, value) in [
            ('자동', m.auto),
            ('수동', m.manual),
            ('반자동', m.semi),
          ])
            _MethodRow(label: label, value: value, total: m.total),
        ],
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = value * 100 / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(child: _Bar(fraction: total == 0 ? 0 : value / total)),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text('${percent.toStringAsFixed(1)}% ($value건)',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 번호 공 + 막대 + 수치 한 줄.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.number,
    required this.value,
    required this.max,
    required this.suffix,
  });

  final int number;
  final int value;
  final int max;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Ball(number, size: 30),
          const SizedBox(width: 12),
          Expanded(child: _Bar(fraction: max == 0 ? 0 : value / max)),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            child: Text(suffix,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  /// 0~1. 가장 큰 값이 1이 되도록 호출부가 맞춰 넘긴다.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction.clamp(0, 1),
        minHeight: 8,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}
