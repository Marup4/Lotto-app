import 'package:flutter/material.dart';

import 'data/draw_repository.dart';
import 'domain/draw.dart';
import 'ui/draw_tab.dart';
import 'ui/my_numbers_tab.dart';

void main() => runApp(const LottoApp());

class LottoApp extends StatelessWidget {
  const LottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로또 번호 확인',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B6FD4)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// 하단 탭 5개 (설계 문서 §8).
/// ①만 구현돼 있고 나머지는 순차 착수한다.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repository = DrawRepository();
  late final Future<List<Draw>> _draws = _repository.loadAll();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로또 번호 확인')),
      // 탭을 오갈 때 데이터를 다시 읽지 않도록 한 번 만든 Future를 재사용한다.
      body: FutureBuilder<List<Draw>>(
        future: _draws,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // 설계 원칙: 에러 화면으로 사용자를 막지 않는다.
            return Center(
              child: Text('데이터를 읽지 못했습니다\n${snapshot.error}',
                  textAlign: TextAlign.center),
            );
          }
          final draws = snapshot.data;
          if (draws == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (_tab) {
            0 => DrawTab(draws: draws),
            1 => MyNumbersTab(draws: draws),
            _ => const _ComingSoon(),
          };
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined), label: '당첨번호'),
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline), label: '내 번호'),
          NavigationDestination(
              icon: Icon(Icons.casino_outlined), label: '번호추천'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: '통계'),
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), label: '판매점'),
        ],
      ),
    );
  }

}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('준비 중', style: TextStyle(color: Colors.grey)));
}
