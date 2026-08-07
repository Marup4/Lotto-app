import 'package:flutter/material.dart';

import '../data/my_numbers_repository.dart';
import '../domain/draw.dart';
import '../domain/match_result.dart';
import '../domain/my_numbers.dart';
import '../domain/prize.dart';
import 'number_grid.dart';
import 'ticket_check_page.dart';

/// ② 내 번호 탭 (설계 문서 §8).
///
/// 저장한 번호를 최신 회차에 자동으로 대조한다. 신규 회차가 들어오면
/// 사용자가 아무것도 하지 않아도 다시 판정된다.
class MyNumbersTab extends StatefulWidget {
  const MyNumbersTab({super.key, required this.draws, this.repository});

  /// 회차 오름차순.
  final List<Draw> draws;
  final MyNumbersRepository? repository;

  @override
  State<MyNumbersTab> createState() => _MyNumbersTabState();
}

class _MyNumbersTabState extends State<MyNumbersTab> {
  late final MyNumbersRepository _repo =
      widget.repository ?? MyNumbersRepository();
  late Future<List<MyNumbers>> _entries = _repo.loadAll();

  /// 대조 기준 회차. 기본은 최신 — 신규 회차가 들어오면 자동으로 그쪽이 된다.
  late int _round = widget.draws.last.round;

  Draw get _draw => widget.draws.firstWhere((d) => d.round == _round);

  void _reload() {
    // 화살표 본문으로 쓰면 대입식의 값(Future)이 반환돼 setState가 거부한다.
    setState(() {
      _entries = _repo.loadAll();
    });
  }

  Future<void> _addNumbers() async {
    final numbers = await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(builder: (_) => const _NumberEntryPage()),
    );
    if (numbers == null) return;

    final existing = await _repo.loadAll();
    await _repo.add(MyNumbers(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      numbers: numbers,
      label: _nextLabel(existing),
      createdAt: DateTime.now(),
    ));
    _reload();
  }

  /// A~E 를 돌려 쓴다. 여러 게임을 한눈에 구분하기 위한 것뿐이다.
  static String _nextLabel(List<MyNumbers> existing) =>
      String.fromCharCode('A'.codeUnitAt(0) + existing.length % 5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 매주 산 용지는 저장할 대상이 아니다. 찍고 확인하면 끝나는
          // 일회성 흐름을 고정번호 목록과 분리해 위에 둔다.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TicketCheckPage(draws: widget.draws),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('용지 QR로 바로 확인'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
          _RoundBar(
            draws: widget.draws,
            selected: _round,
            onSelected: (r) => setState(() => _round = r),
          ),
          Expanded(
            child: FutureBuilder<List<MyNumbers>>(
              future: _entries,
              builder: (context, snapshot) {
                final entries = snapshot.data;
                if (entries == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (entries.isEmpty) return const _Empty();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _EntryCard(
                    entry: entries[i],
                    draw: _draw,
                    onDelete: () async {
                      await _repo.remove(entries[i].id);
                      _reload();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNumbers,
        icon: const Icon(Icons.add),
        label: const Text('번호 추가'),
      ),
    );
  }
}

class _RoundBar extends StatelessWidget {
  const _RoundBar({
    required this.draws,
    required this.selected,
    required this.onSelected,
  });

  final List<Draw> draws;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          DropdownButton<int>(
            value: selected,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: [
              for (final d in draws.reversed)
                DropdownMenuItem(value: d.round, child: Text('${d.round}회')),
            ],
            onChanged: (r) {
              if (r != null) onSelected(r);
            },
          ),
          const SizedBox(width: 4),
          Text('기준으로 대조', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.draw,
    required this.onDelete,
  });

  final MyNumbers entry;
  final Draw draw;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final result = MatchResult.of(mine: entry.numbers, draw: draw);
    final won = result.rank != Rank.none;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(entry.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 10),
                _RankChip(rank: result.rank, hasBonus: result.hasBonus),
                const Spacer(),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                ),
              ],
            ),
            const SizedBox(height: 4),
            MatchedNumberRow(
              numbers: entry.numbers,
              matched: result.matched,
              bonus: result.hasBonus ? draw.bonus : null,
            ),
            const SizedBox(height: 10),
            Text(
              won
                  ? '${result.matched.length}개 일치'
                      '${result.hasBonus ? " + 보너스" : ""}'
                  : '${result.matched.length}개 일치',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank, required this.hasBonus});

  final Rank rank;
  final bool hasBonus;

  @override
  Widget build(BuildContext context) {
    final won = rank != Rank.none;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: won ? const Color(0xFF2E7D32) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rankLabel(rank),
        style: TextStyle(
          color: won ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('저장한 번호가 없습니다',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('번호를 추가하면 매주 자동으로 확인해 드립니다',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

/// 번호 입력 화면.
class _NumberEntryPage extends StatefulWidget {
  const _NumberEntryPage();

  @override
  State<_NumberEntryPage> createState() => _NumberEntryPageState();
}

class _NumberEntryPageState extends State<_NumberEntryPage> {
  NumberSelection _selection = const NumberSelection();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('번호 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_selection.numbers.length} / ${NumberSelection.max}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            NumberGrid(
              selection: _selection,
              onToggle: (n) =>
                  setState(() => _selection = _selection.toggle(n)),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _selection.isComplete
                  ? () => Navigator.of(context).pop(_selection.numbers)
                  : null,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
