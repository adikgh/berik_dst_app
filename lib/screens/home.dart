import 'package:flutter/material.dart';

import '../api.dart';
import '../notify.dart';
import '../t.dart';
import 'account.dart';
import 'orders.dart';

/// Сайттағы төменгі мәзір: қосулы тапсырыс түрлері + Аккаунт
class Section {
  final String key;
  final IconData icon;
  final String Function() title;
  final List<(String, String Function())> tabs; // (sort, атауы)
  const Section(this.key, this.icon, this.title, this.tabs);
}

final sections = <Section>[
  Section('delivery', Icons.directions_car_outlined, () => tw('Жеткізу', 'Доставка'), [
    ('new', () => tw('Жаңа', 'Новые')),
    ('road', () => tw('Жолда', 'В пути')),
    ('history', () => tw('Аяқталған', 'Завершённые')),
  ]),
  Section('yourself', Icons.directions_walk, () => tw('Өзімен', 'Собой'), [
    ('myself', () => tw('Жаңа', 'Новые')),
    ('myself_yes', () => tw('Тапсырылған', 'Выданные')),
  ]),
  Section('service', Icons.backpack_outlined, () => tw('Сервис', 'Сервис'), [
    ('service', () => tw('Жаңа', 'Новые')),
    ('service_yes', () => tw('Берілген', 'Выданные')),
  ]),
  Section('coffee', Icons.restaurant_outlined, () => tw('Кафе', 'Кафе'), [
    ('coffee', () => tw('Кафе', 'Кафе')),
  ]),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _me;
  Object? _err;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    Notifier.i.addListener(_onPoll);
    Notifier.i.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Notifier.i.removeListener(_onPoll);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) Notifier.i.start();
  }

  void _onPoll() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _err = null);
    try {
      final d = await Api.i.get('me');
      Api.i.city = '${(d['company'] as Map?)?['city'] ?? 'shymkent'}';
      setState(() => _me = d);
    } catch (e) {
      setState(() => _err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return Scaffold(
        body: Center(
          child: _err == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(errText(_err!)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(tw('Қайталау', 'Повторить'))),
                  TextButton(
                    onPressed: () async {
                      await Api.i.logout();
                      Api.i.onLogout?.call();
                    },
                    child: Text(tw('Шығу', 'Выйти')),
                  ),
                ]),
        ),
      );
    }
    final types = List<String>.from(_me!['types'] as List);
    final secs = sections.where((s) => types.contains(s.key)).toList();
    final pages = <Widget>[
      for (final s in secs) OrdersSection(key: ValueKey('${s.key}-${Api.i.lang}'), section: s),
      AccountScreen(me: _me!, onLang: _load),
    ];
    if (_idx >= pages.length) _idx = 0;
    final cnt = Notifier.i.counts;
    final sortOf = {'delivery': 'new', 'yourself': 'myself', 'service': 'service', 'coffee': 'coffee'};
    return Scaffold(
      body: IndexedStack(index: _idx, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        backgroundColor: Colors.white,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: [
          for (final s in secs)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: (cnt[sortOf[s.key]] ?? 0) > 0,
                label: Text('${cnt[sortOf[s.key]] ?? 0}'),
                child: Icon(s.icon),
              ),
              label: s.title(),
            ),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: tw('Аккаунт', 'Аккаунт')),
        ],
      ),
    );
  }
}
