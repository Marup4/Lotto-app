import 'package:flutter/material.dart';

import '../data/my_numbers_repository.dart';
import '../domain/draw.dart';
import '../domain/my_numbers.dart';
import '../domain/recommender.dart';
import 'ball.dart';
import 'number_grid.dart';

/// ③ 번호 추천 탭 (설계 문서 §8).
///
/// ⚠️ 이 화면은 **재미 요소**다. 설계 문서 §7 F3이 "예측", "확률이 높다"
/// 같은 표현을 전면 금지했다. 사실 서술만 쓰고, 통계와 당첨 확률이
/// 무관하다는 안내를 화면에 고정 노출한다. 심사 대응이자 정직성 문제다.
class RecommendTab extends StatefulWidget {
  const RecommendTab({super.key, required this.draws, this.repository});

  /// 회차 오름차순. 빈도 계산에 쓴다.
  final List<Draw> draws;
  final MyNumbersRepository? repository;

  @override
  State<RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<RecommendTab> {
  late final MyNumbersRepository _repo =
      widget.repository ?? MyNumbersRepository();

  PickMode _mode = PickMode.random;
  final _excluded = <int>{};
  final _fixed = <int>{};
  List<int>? _result;
  bool _saved = false;

  /// 번들된 회차에서 센 출현 횟수. 설명에 회차 수를 그대로 밝힌다.
  late final Map<int, int> _frequency = () {
    final counts = {for (var n = 1; n <= 45; n++) n: 0};
    for (final d in widget.draws) {
      for (final n in d.numbers) {
        counts[n] = counts[n]! + 1;
      }
    }
    return counts;
  }();

  void _generate() {
    setState(() {
      _saved = false;
      _result = recommend(
        mode: _mode,
        excluded: _excluded,
        fixed: _fixed,
        frequency: _frequency,
      );
    });
  }

  Future<void> _save() async {
    final existing = await _repo.loadAll();
    await _repo.add(MyNumbers(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      numbers: _result!,
      label: String.fromCharCode('A'.codeUnitAt(0) + existing.length % 5),
      createdAt: DateTime.now(),
    ));
    if (mounted) setState(() => _saved = true);
  }

  /// 고정 6개를 이미 채웠거나 남은 번호가 모자라면 만들 수 없다.
  bool get _canGenerate {
    final available = 45 - _excluded.difference(_fixed).length;
    return _fixed.length <= 6 && available >= 6;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        _ModeSelector(
          mode: _mode,
          rounds: widget.draws.length,
          onChanged: (m) => setState(() => _mode = m),
        ),
        const SizedBox(height: 20),
        _PickerSection(
          title: '고정할 번호',
          hint: '고른 번호는 반드시 포함됩니다',
          selected: _fixed,
          max: 6,
          onToggle: (n) => setState(() {
            if (!_fixed.remove(n) && _fixed.length < 6) {
              _fixed.add(n);
              _excluded.remove(n); // 고정이 제외를 이긴다
            }
          }),
        ),
        const SizedBox(height: 16),
        _PickerSection(
          title: '제외할 번호',
          hint: '고른 번호는 나오지 않습니다',
          selected: _excluded,
          onToggle: (n) => setState(() {
            if (!_excluded.remove(n)) {
              _excluded.add(n);
              _fixed.remove(n);
            }
          }),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _canGenerate ? _generate : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('번호 뽑기'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 24),
          _Result(numbers: _result!, saved: _saved, onSave: _save),
        ],
        const SizedBox(height: 28),
        const _Disclaimer(),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.rounds,
    required this.onChanged,
  });

  final PickMode mode;
  final int rounds;
  final ValueChanged<PickMode> onChanged;

  // 문구는 전부 사실 서술이다. "확률", "예측"이라는 말을 쓰지 않는다.
  String _label(PickMode m) => switch (m) {
        PickMode.random => '완전 무작위',
        PickMode.hot => '최근 $rounds회차에서 많이 나온 번호로',
        PickMode.cold => '최근 $rounds회차에서 적게 나온 번호로',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('뽑는 방식', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        RadioGroup<PickMode>(
          groupValue: mode,
          onChanged: (v) => onChanged(v!),
          child: Column(
            children: [
              for (final m in PickMode.values)
                RadioListTile<PickMode>(
                  value: m,
                  title:
                      Text(_label(m), style: const TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerSection extends StatefulWidget {
  const _PickerSection({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onToggle,
    this.max,
  });

  final String title;
  final String hint;
  final Set<int> selected;
  final int? max;
  final ValueChanged<int> onToggle;

  @override
  State<_PickerSection> createState() => _PickerSectionState();
}

class _PickerSectionState extends State<_PickerSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(widget.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                if (count > 0)
                  Text('$count개',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                const Spacer(),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (count > 0 && !_open)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in widget.selected.toList()..sort())
                Ball(n, size: 30)
            ],
          ),
        if (_open) ...[
          Text(widget.hint,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          NumberGrid(
            selection: NumberSelection(widget.selected.toList()..sort()),
            onToggle: widget.onToggle,
            max: widget.max,
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.numbers,
    required this.saved,
    required this.onSave,
  });

  final List<int> numbers;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final n in numbers) Ball(n)],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: saved ? null : onSave,
              icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(saved ? '내 번호에 저장됨' : '내 번호에 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 설계 문서 §7 F3·§12가 요구하는 고정 안내.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '지난 회차의 출현 빈도는 다음 추첨 결과와 아무런 관계가 없습니다. '
        '모든 번호의 당첨 확률은 같습니다. 이 기능은 번호를 고르는 재미를 '
        '위한 것입니다.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }
}
