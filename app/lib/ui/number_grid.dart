import 'package:flutter/material.dart';

import '../domain/my_numbers.dart';
import 'ball.dart';

/// 1~45 그리드 입력 (설계 문서 §7 F2).
///
/// 키패드 대신 그리드를 쓰는 이유는 오입력을 줄이기 위함이다.
/// 고른 번호는 실제 볼 색상으로 채워 결과 화면과 인상을 맞춘다.
class NumberGrid extends StatelessWidget {
  const NumberGrid({
    super.key,
    required this.selection,
    required this.onToggle,
    this.max = NumberSelection.max,
  });

  final NumberSelection selection;
  final ValueChanged<int> onToggle;

  /// 고를 수 있는 최대 개수. null이면 제한이 없다 (제외 번호 지정 등).
  final int? max;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 45,
      itemBuilder: (context, i) {
        final n = i + 1;
        final picked = selection.contains(n);
        // 상한을 채운 뒤에는 고르지 않은 칸을 눌러도 소용없다.
        // 눌리지 않는다는 것을 흐리게 표시해 알려준다.
        final full = max != null && selection.numbers.length >= max!;
        return _GridCell(
          number: n,
          picked: picked,
          enabled: picked || !full,
          onTap: () => onToggle(n),
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.number,
    required this.picked,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final bool picked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (picked) {
      return GestureDetector(
        onTap: onTap,
        child: Ball(number, size: 40),
      );
    }
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Text('$number',
              style: TextStyle(color: Colors.grey.shade700)),
        ),
      ),
    );
  }
}

/// 결과 화면에서 쓰는, 맞은 번호만 강조한 한 줄.
class MatchedNumberRow extends StatelessWidget {
  const MatchedNumberRow({
    super.key,
    required this.numbers,
    required this.matched,
    required this.bonus,
  });

  final List<int> numbers;
  final List<int> matched;
  final int? bonus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final n in numbers)
          if (matched.contains(n) || n == bonus)
            Ball(n, size: 34)
          else
            _Faded(n),
      ],
    );
  }
}

class _Faded extends StatelessWidget {
  const _Faded(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$number',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
    );
  }
}
