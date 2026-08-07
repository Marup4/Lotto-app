import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/draw.dart';
import '../domain/match_result.dart';
import '../domain/prize.dart';
import '../domain/ticket.dart';
import 'number_grid.dart';

/// 앱이 담고 있지 않은 회차의 용지를 찍었을 때 보여줄 말.
///
/// "없는 회차"라고만 하면 고장으로 보인다. 오래된 용지라면
/// **당첨금 지급 기한(1년)이 지나 수령 자체가 불가능하다**는 것이
/// 사용자에게 훨씬 쓸모 있는 정보다.
String outOfRangeMessage(int round, List<Draw> draws) {
  // "1136~1235회"는 외울 수도 가늠할 수도 없는 숫자다. 개수로 말한다.
  final range = '이 앱은 최근 ${draws.length}회차를 확인할 수 있습니다.';

  if (round < draws.first.round) {
    return '$round회는 당첨금 지급 기한(1년)이 지난 회차입니다. $range';
  }
  return '$round회 자료가 아직 없습니다. $range';
}

/// QR로 읽은 용지를 그 자리에서 확인한다. 저장하지 않는다.
///
/// 매주 5~10장을 사는 사람에게 번호를 일일이 넣고 나중에 지우게 하는 것은
/// 무리다. 여러 장을 연달아 찍고 결과를 쌓아 보는 흐름이 필요하다.
/// 공식 QR 확인은 장마다 브라우저를 왕복해야 해서 이걸 못 한다.
class TicketCheckPage extends StatefulWidget {
  const TicketCheckPage({super.key, required this.draws});

  /// 회차 오름차순.
  final List<Draw> draws;

  @override
  State<TicketCheckPage> createState() => _TicketCheckPageState();
}

class _TicketCheckPageState extends State<TicketCheckPage> {
  final _scanned = <Ticket>[];
  final _seenCodes = <String>{};
  String? _warning;

  Draw? _drawFor(int? round) {
    if (round == null) return null;
    for (final d in widget.draws) {
      if (d.round == round) return d;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || !_seenCodes.add(raw)) continue; // 같은 장 중복 방지

      final ticket = Ticket.fromQr(raw);
      setState(() {
        if (ticket == null) {
          _warning = '로또 용지의 QR이 아닙니다';
        } else if (_drawFor(ticket.round) == null) {
          _warning = outOfRangeMessage(ticket.round!, widget.draws);
        } else {
          _warning = null;
          _scanned.insert(0, ticket);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('용지 확인'),
        actions: [
          if (_scanned.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _scanned.clear();
                _seenCodes.clear();
              }),
              child: const Text('지우기'),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                MobileScanner(onDetect: _onDetect),
                if (_warning != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.7),
                      padding: const EdgeInsets.all(10),
                      child: Text(_warning!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _scanned.isEmpty
                ? const _ScanHint()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _scanned.length,
                    itemBuilder: (context, i) => TicketCard(
                      ticket: _scanned[i],
                      draw: _drawFor(_scanned[i].round)!,
                      index: _scanned.length - i,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner,
                size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('용지의 QR을 비춰주세요',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Text('여러 장을 연달아 찍을 수 있습니다',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

/// 용지 한 장의 결과.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    required this.draw,
    required this.index,
  });

  final Ticket ticket;
  final Draw draw;
  final int index;

  @override
  Widget build(BuildContext context) {
    final best = ticket.bestRank(draw);
    final results = ticket.check(draw);
    final won = best != Rank.none;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$index번째 장 · ${ticket.round}회',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _Summary(best: best, count: ticket.winningCount(draw)),
              ],
            ),
            const Divider(height: 20),
            for (var i = 0; i < results.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(ticket.labels[i],
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                  Expanded(
                    child: MatchedNumberRow(
                      numbers: ticket.games[i],
                      matched: results[i].matched,
                      bonus: results[i].hasBonus ? draw.bonus : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rankLabel(results[i].rank),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: results[i].rank != Rank.none
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: results[i].rank != Rank.none
                          ? const Color(0xFF2E7D32)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (i < results.length - 1) const SizedBox(height: 8),
            ],
            // 큰 당첨은 우리가 단정할 자리가 아니다. 수령은 공식 절차다.
            if (best.index <= Rank.third.index && won) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '높은 등수입니다. 반드시 동행복권에서 공식 확인 후 수령하세요.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8A5300)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.best, required this.count});

  final Rank best;
  final int count;

  @override
  Widget build(BuildContext context) {
    final won = best != Rank.none;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: won ? const Color(0xFF2E7D32) : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        won ? '${rankLabel(best)} $count게임' : '미당첨',
        style: TextStyle(
          color: won ? Colors.white : Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
