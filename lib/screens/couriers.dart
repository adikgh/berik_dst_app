import 'package:flutter/material.dart';

import '../api.dart';
import '../t.dart';
import '../widgets/order_card.dart';
import 'orders.dart';

/// Курьерлер: тізім, қосу, өзгерту, өшіру (сайттағы /users/ беті)
class CouriersScreen extends StatefulWidget {
  const CouriersScreen({super.key});

  @override
  State<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends State<CouriersScreen> {
  List<Map<String, dynamic>>? _list;
  Object? _err;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Couriers.load(force: true);
      if (mounted) setState(() => _list = l);
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _edit([Map<String, dynamic>? c]) async {
    final n = TextEditingController(text: c == null ? '' : '${c['name']}');
    final p = TextEditingController(text: c == null ? '' : '${c['phone']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? tw('Курьер қосу', 'Добавить курьера') : tw('Курьерді өзгерту', 'Изменить курьера')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: InputDecoration(labelText: tw('Аты', 'Имя'))),
          const SizedBox(height: 10),
          TextField(
            controller: p,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tw('Нөмір', 'Номер'), hintText: '8 (700) 000-00-00'),
          ),
          if (c == null) ...[
            const SizedBox(height: 8),
            Text(tw('Жаңа курьердің құпиясөзі: 123456', 'Пароль нового курьера: 123456'),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tw('Болдырмау', 'Отмена'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tw('Сақтау', 'Сохранить'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (c == null) {
        await Api.i.post('courier_add', {'name': n.text.trim(), 'phone': p.text});
      } else {
        await Api.i.post('courier_edit', {'id': c['id'], 'name': n.text.trim(), 'phone': p.text});
      }
      await _load();
    } catch (e) {
      _snack(errText(e));
    }
  }

  Future<void> _del(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tw('Курьерді тізімнен өшіру керек пе?', 'Удалить курьера из списка?')),
        content: Text('${c['name']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tw('Жоқ', 'Нет'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tw('Өшіру', 'Удалить')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.post('courier_del', {'staff_id': c['staff_id']});
      await _load();
    } catch (e) {
      _snack(errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = (_list ?? [])
        .where((c) => _q.isEmpty || '${c['name']} ${c['phone']}'.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text('${tw('Курьерлер', 'Курьеры')}${_list == null ? '' : ' · ${_list!.length}'}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: Text(tw('Қосу', 'Добавить')),
      ),
      body: _list == null
          ? Center(child: _err == null ? const CircularProgressIndicator() : Text(errText(_err!)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tw('Іздеу', 'Поиск')),
                ),
                const SizedBox(height: 12),
                for (final c in list) ...[
                  Card(
                    child: ListTile(
                      onTap: () => _edit(c),
                      leading: CircleAvatar(
                        backgroundImage: '${c['img']}'.isEmpty ? null : NetworkImage(Api.i.img('${c['img']}')),
                        child: '${c['img']}'.isEmpty ? Text('${c['name']}'.trim().isEmpty ? '?' : '${c['name']}'.trim()[0].toUpperCase()) : null,
                      ),
                      title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(phoneFmt('${c['phone']}')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => openUrl('tel:8${c['phone']}')),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _del(c)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ]),
            ),
    );
  }
}
