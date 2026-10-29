import 'package:flutter/material.dart';

import '../api.dart';
import '../t.dart';
import '../widgets/order_card.dart';

/// «Толығырақ»: тапсырыс карточкасы, толық мәлімет, статус тарихы және өзгерістер
class OrderDetailScreen extends StatefulWidget {
  final int id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _o;
  Object? _err;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.i.get('order', {'id': '${widget.id}'});
      if (mounted) setState(() => _o = d['order'] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? tw('Тапсырыс', 'Заказ') : '№ ${o['number']}')),
      body: o == null
          ? Center(child: _err == null ? const CircularProgressIndicator() : Text(errText(_err!)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                OrderCard(order: o, sort: 'item', full: true, onChanged: _load),
                const SizedBox(height: 12),
                _box(tw('Толық мәлімет', 'Полная информация'), _info(o)),
                const SizedBox(height: 12),
                _box(tw('Тарих', 'История'), _history(o)),
              ]),
            ),
    );
  }

  Widget _box(String h, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(h, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget _info(Map<String, dynamic> o) {
    final ph = '${o['phone']}';
    final rows = <(String, String)>[
      (tw('Түрі', 'Тип'), '${o['type_name']}'),
      (tw('Точка', 'Точка'), '${o['branch'] ?? ''}'),
      (tw('Клиент нөмірі', 'Номер клиента'), ph.isEmpty ? '' : phoneFmt(ph)),
      (tw('Предзаказ', 'Предзаказ'), '${o['preorder']}'),
      (tw('Төлем', 'Оплата'), '${o['payment_method']}'),
      (tw('Қосымша', 'Примечание'), '${o['additional'] ?? ''}'),
      (tw('Пікір', 'Комментарий'), '${o['comment'] ?? ''}'),
      (tw('Жасалды', 'Создан'), _dt('${o['created']}')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in rows)
        if (r.$2.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text('${r.$1}:', style: const TextStyle(color: Colors.black54))),
              Expanded(child: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
      if (ph.length == 10) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => openUrl('tel:8$ph'),
              icon: const Icon(Icons.call),
              label: Text(tw('Қоңырау', 'Звонок')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
              onPressed: () => openUrl('https://wa.me/7$ph'),
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
            ),
          ),
        ]),
      ],
    ]);
  }

  Widget _history(Map<String, dynamic> o) {
    final rows = List<Map<String, dynamic>>.from(o['history'] as List? ?? []);
    final ch = List<Map<String, dynamic>>.from(o['changes'] as List? ?? []);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: 0, label: Text(tw('Статус', 'Статус'))),
          ButtonSegment(value: 1, label: Text('${tw('Өзгерістер', 'Изменения')}${ch.isEmpty ? '' : ' (${ch.length})'}')),
        ],
        selected: {_tab},
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      ),
      const SizedBox(height: 12),
      if (_tab == 0) ...[
        for (var i = 0; i < rows.length; i++) _stRow(rows[i], i == rows.length - 1),
        const Divider(),
        if ('${o['updated'] ?? ''}'.isNotEmpty) _kv(tw('Соңғы өзгеріс', 'Последнее изменение'), _dt('${o['updated']}')),
        _kv(tw('Тапсырыс авторы', 'Автор заказа'), '${o['operator']}'),
      ] else if (ch.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tw('Әзірге өзгеріс жоқ', 'Изменений пока нет'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45)),
        )
      else
        for (final c in ch) _chRow(c),
    ]);
  }

  Widget _stRow(Map<String, dynamic> r, bool last) {
    final on = r['on'] == true;
    final cur = r['current'] == true;
    final skip = r['skip'] == true;
    final clr = on ? hexColor(r['color'], Colors.grey) : const Color(0xFFCFD4D9);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 24,
          child: Column(children: [
            Container(
              width: cur ? 16 : 12,
              height: cur ? 16 : 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: on ? clr : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: clr, width: 2),
              ),
            ),
            if (!last) Expanded(child: Container(width: 2, color: on && !cur ? clr : const Color(0xFFE3E6E9))),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Expanded(
                child: Text('${r['name']}',
                    style: TextStyle(
                      fontWeight: cur ? FontWeight.w800 : FontWeight.w500,
                      color: on ? Colors.black87 : Colors.black38,
                      decoration: skip ? TextDecoration.lineThrough : null,
                    )),
              ),
              if ('${r['dt']}'.isNotEmpty)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_hm('${r['dt']}'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(_d('${r['dt']}'), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chRow(Map<String, dynamic> c) {
    final parts = List<Map<String, dynamic>>.from(c['parts'] as List? ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['field']}', style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${c['meta']}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (var i = 0; i < parts.length; i++) ...[
            Text('${parts[i]['t']}',
                style: TextStyle(
                  decoration: parts[i]['k'] == 'old' ? TextDecoration.lineThrough : null,
                  color: parts[i]['k'] == 'old' ? Colors.black45 : Colors.black87,
                  fontWeight: parts[i]['k'] == 'new' ? FontWeight.w800 : FontWeight.w500,
                )),
          ],
        ]),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  DateTime? _p(String s) => DateTime.tryParse(s.replaceFirst(' ', 'T'));
  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(String s) {
    final d = _p(s);
    return d == null ? s : '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _d(String s) {
    final d = _p(s);
    return d == null ? '' : '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }

  String _dt(String s) => s.isEmpty ? '' : '${_hm(s)} ${_d(s)}';
}
