import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../t.dart';
import '../screens/order_detail.dart';
import '../screens/orders.dart';

Color hexColor(Object? v, [Color def = const Color(0xFF10A96A)]) {
  final s = '${v ?? ''}'.replaceAll('#', '').trim();
  if (s.length == 6) {
    final n = int.tryParse(s, radix: 16);
    if (n != null) return Color(0xFF000000 | n);
  }
  return def;
}

Future<void> openUrl(String u) async {
  await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
}

/// Курьер таңдау терезесі. Таңдалса тапсырыс серверде өзгереді.
Future<bool> pickCourier(BuildContext context, Map<String, dynamic> o) async {
  List<Map<String, dynamic>> cs;
  try {
    cs = await Couriers.load();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    return false;
  }
  if (!context.mounted) return false;
  final cur = (o['courier_id'] as num?)?.toInt() ?? 0;
  final r = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(tw('Курьер таңдау', 'Выбрать курьера'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (cur > 0)
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFDECEC), child: Icon(Icons.person_off_outlined, color: Colors.red)),
              title: Text(tw('Курьерді алып тастау', 'Убрать курьера'), style: const TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 0),
            ),
          for (final c in cs)
            ListTile(
              leading: CircleAvatar(child: Text('${c['name']}'.trim().isEmpty ? '?' : '${c['name']}'.trim()[0].toUpperCase())),
              title: Text('${c['name']}'),
              trailing: cur == c['id'] ? const Icon(Icons.check, color: Color(0xFF0EA768)) : null,
              onTap: () => Navigator.pop(ctx, (c['id'] as num).toInt()),
            ),
        ]),
      ),
    ),
  );
  if (r == null || r == cur) return false;
  try {
    await Api.i.post('assign', {'order_id': o['id'], 'courier_id': r});
    return true;
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    return true; // тізім жаңарсын (мысалы курьер жолға шығып кеткен)
  }
}

Future<bool> doAction(BuildContext context, String a, int id) async {
  try {
    await Api.i.post(a, {'id': id});
    return true;
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    return true;
  }
}

class OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String sort;
  final bool full;
  final Future<void> Function() onChanged;
  const OrderCard({super.key, required this.order, required this.sort, required this.onChanged, this.full = false});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _more = false;
  bool _busy = false;

  Map<String, dynamic> get o => widget.order;

  Future<void> _run(Future<bool> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    final changed = await f();
    if (changed) await widget.onChanged();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = (o['status'] as num).toInt();
    final type = (o['type'] as num).toInt();
    final clr = hexColor(o['status_color']);
    final items = List<Map<String, dynamic>>.from(o['items'] as List? ?? []);
    final fold = items.length >= 3 && !widget.full && !_more;
    final shown = fold ? items.take(2).toList() : items;
    final closed = [5, 6, 10].contains(st);
    final isCar = type == 1 && !closed;
    final mapOn = isCar && widget.sort != 'history';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: clr, width: 5))),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Нөмір, статус, уақыт
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o['number']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (st != 11 && '${o['status_name']}'.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: clr.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
                    child: Text('${o['status_name']}', style: TextStyle(color: clr, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                if ('${o['preorder']}'.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_active_outlined, size: 14, color: Colors.orange),
                    const SizedBox(width: 2),
                    Text('${o['preorder']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
              ]),
            ),
            Text('${o['time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),

          // Әрекеттер: Берілді / Столда
          if (o['can_give'] == true || o['can_table'] == true) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() => doAction(context, o['can_table'] == true ? 'table' : 'give', (o['id'] as num).toInt())),
              icon: Icon(o['can_table'] == true ? Icons.restaurant : Icons.check),
              label: Text(o['can_table'] == true ? tw('Столда', 'На столе') : tw('Берілді', 'Выдан')),
            ),
          ],

          // Курьер
          if (isCar) ...[
            const SizedBox(height: 10),
            _CourierRow(
              name: '${o['courier_name']}',
              can: o['courier_can_change'] == true,
              busy: _busy,
              onTap: () => _run(() => pickCourier(context, o)),
            ),
          ],

          // Тағамдар
          const _Div(),
          _row(tw('Атауы', 'Название'), tw('Саны', 'Кол-во'), tw('Бағасы', 'Сумма'), muted: true),
          for (var i = 0; i < shown.length; i++)
            _row('${i + 1}. ${shown[i]['name']}', '${_qty(shown[i]['qty'])} шт', money(shown[i]['sum'] as num)),
          if (items.length >= 3 && !widget.full)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _more = !_more),
                icon: Icon(_more ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(_more ? tw('Жасыру', 'Скрыть') : '+${items.length - 2} ${tw('тағы', 'ещё')}'),
              ),
            ),
          if (type == 1) _row(tw('Жеткізу', 'Доставка'), '', money(o['delivery'] as num)),
          const SizedBox(height: 4),
          _row(tw('Жалпы', 'Итого'), '', money(o['total'] as num), bold: true),

          // Төлем
          if (type == 1 || type == 2) ...[
            const _Div(),
            _row(
              tw('Алдын ала төлем', 'Предоплата') +
                  ('${o['prepay_method']}'.isNotEmpty ? ' (${o['prepay_method']})' : ''),
              '-',
              money(o['prepay'] as num),
            ),
            _row(type == 1 ? tw('Курьерге (нал)', 'Курьеру (нал)') : tw('Алғанда төлейді', 'Оплата при получении'), '',
                money(o['pay_cash'] as num),
                bold: true),
          ] else if (type == 4 && '${o['payment_method']}'.isNotEmpty) ...[
            const _Div(),
            _row(tw('Төлем', 'Оплата'), '', '${o['payment_method']}'),
          ],

          // Бас тарту себебі
          if (closed && ('${o['refuse_reason']}'.isNotEmpty || (o['kept_sum'] as num) > 0)) ...[
            const _Div(),
            _info(tw('Себебі', 'Причина'), '${o['refuse_reason']}'.isEmpty ? '—' : '${o['refuse_reason']}'),
            if ((o['kept_sum'] as num) > 0) _info(tw('Бізде қалды', 'Осталось у нас'), money(o['kept_sum'] as num)),
          ],

          // Мекенжай
          if ('${o['address']}'.isNotEmpty) ...[
            const _Div(),
            _info(tw('Оператор', 'Оператор'), '${o['operator']}'),
            _info(tw('Мекенжай', 'Адрес'), '${o['address']}'),
            if ('${o['floor_apt']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.apartment, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${o['floor_apt']}'.replaceAll(', ', ' · '), style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            if (mapOn) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => openUrl('https://2gis.kz/${Uri.encodeComponent(Api.i.city)}/search/${Uri.encodeComponent('${o['address']}')}'),
                icon: const Icon(Icons.map_outlined),
                label: Text('${tw('Картадан ашу', 'Открыть на карте')} · 2GIS'),
              ),
            ],
          ],

          if (!widget.full) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(id: (o['id'] as num).toInt())));
                await widget.onChanged();
              },
              child: Text(tw('Толығырақ', 'Подробнее')),
            ),
          ],
        ]),
      ),
    );
  }

  String _qty(Object? q) {
    final n = (q as num?) ?? 0;
    return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  }

  Widget _row(String a, String b, String c, {bool bold = false, bool muted = false}) {
    final s = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: muted ? Colors.black45 : Colors.black87,
      fontSize: muted ? 12 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 6, child: Text(a, style: s)),
        Expanded(flex: 2, child: Text(b, style: s, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text(c, style: s, textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 92, child: Text('$k:', style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _CourierRow extends StatelessWidget {
  final String name;
  final bool can;
  final bool busy;
  final VoidCallback onTap;
  const _CourierRow({required this.name, required this.can, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6F8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: can && !busy ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Icon(Icons.two_wheeler, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(tw('Курьер', 'Курьер'), style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              Text(name.isNotEmpty ? name : tw('Таңдау', 'Выбрать'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: name.isNotEmpty ? Colors.black87 : const Color(0xFF0EA768))),
              const SizedBox(width: 4),
              Icon(can ? Icons.expand_more : Icons.lock_outline, size: 18, color: Colors.black45),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, color: Color(0xFFE8EBEE)),
      );
}
