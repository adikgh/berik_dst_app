import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../notify.dart';
import '../t.dart';
import '../widgets/order_card.dart';
import 'home.dart';

/// Бір бөлім (Жеткізу, Өзімен, ...): жоғарыда ішкі қойындылар
class OrdersSection extends StatelessWidget {
  final Section section;
  const OrdersSection({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final tabs = section.tabs;
    if (tabs.length == 1) {
      return Scaffold(
        appBar: AppBar(title: Text(section.title(), style: const TextStyle(fontWeight: FontWeight.w800))),
        body: OrdersList(sort: tabs.first.$1),
      );
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(section.title(), style: const TextStyle(fontWeight: FontWeight.w800)),
          bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$2())]),
        ),
        body: TabBarView(children: [for (final t in tabs) OrdersList(sort: t.$1)]),
      ),
    );
  }
}

/// Курьерлер тізімі (бір рет жүктеліп, сақталады)
class Couriers {
  static List<Map<String, dynamic>>? list;
  static Future<List<Map<String, dynamic>>> load({bool force = false}) async {
    if (list != null && !force) return list!;
    final d = await Api.i.get('couriers');
    list = List<Map<String, dynamic>>.from(d['couriers'] as List);
    return list!;
  }
}

class OrdersList extends StatefulWidget {
  final String sort;
  const OrdersList({super.key, required this.sort});

  @override
  State<OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<OrdersList> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>>? _orders;
  Object? _err;
  int _staff = 0;
  String _staffName = '';
  int _ver = -1;
  Timer? _timer;

  bool get _hasFilter => widget.sort == 'road' || widget.sort == 'history';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    Notifier.i.addListener(_onPoll);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    Notifier.i.removeListener(_onPoll);
    super.dispose();
  }

  void _onPoll() {
    if (_ver != Notifier.i.version) _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    _ver = Notifier.i.version;
    if (!quiet) setState(() => _err = null);
    try {
      final d = await Api.i.get('orders', {'sort': widget.sort, if (_staff > 0) 'staff': '$_staff'});
      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(d['orders'] as List);
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!quiet || _orders == null) setState(() => _err = e);
    }
  }

  Future<void> _pickFilter() async {
    List<Map<String, dynamic>> cs;
    try {
      cs = await Couriers.load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
      return;
    }
    if (!mounted) return;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
            title: Text(tw('Барлық курьерлер', 'Все курьеры')),
            trailing: _staff == 0 ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(ctx, {'id': 0, 'name': ''}),
          ),
          for (final c in cs)
            ListTile(
              leading: CircleAvatar(child: Text(_initial(c['name']))),
              title: Text('${c['name']}'),
              trailing: _staff == c['id'] ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, c),
            ),
        ]),
      ),
    );
    if (r == null) return;
    setState(() {
      _staff = (r['id'] as num).toInt();
      _staffName = '${r['name']}';
      _orders = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget body;
    if (_orders == null && _err == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_orders == null) {
      body = ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text(errText(_err!))),
        Center(child: TextButton(onPressed: _load, child: Text(tw('Қайталау', 'Повторить')))),
      ]);
    } else if (_orders!.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.inbox_outlined, size: 56, color: Colors.black26),
        const SizedBox(height: 8),
        Center(child: Text(tw('Тапсырыс жоқ', 'Заказов нет'), style: const TextStyle(color: Colors.black45))),
      ]);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: _orders!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => OrderCard(order: _orders![i], sort: widget.sort, onChanged: _load),
      );
    }
    return Column(children: [
      if (_hasFilter)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Material(
            color: _staff > 0 ? const Color(0xFFE6F6EF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.person_outline),
              title: Text(tw('Курьер бойынша', 'По курьеру'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
              subtitle: Text(_staff > 0 ? _staffName : tw('Барлық курьерлер', 'Все курьеры'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
              trailing: const Icon(Icons.expand_more),
              onTap: _pickFilter,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text(tw('Тапсырыс', 'Заказы'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 6),
          Text('${_orders?.length ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      Expanded(child: RefreshIndicator(onRefresh: _load, child: body)),
    ]);
  }
}

String _initial(Object? n) {
  final s = '${n ?? ''}'.trim();
  return s.isEmpty ? '?' : s.substring(0, 1).toUpperCase();
}
