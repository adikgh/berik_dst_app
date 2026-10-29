import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../notify.dart';
import '../t.dart';
import '../widgets/order_card.dart';
import 'couriers.dart';
import 'login.dart';
import 'orders.dart';

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic> me;
  final Future<void> Function() onLang;
  const AccountScreen({super.key, required this.me, required this.onLang});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _password() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tw('Құпиясөзді өзгерту', 'Сменить пароль')),
        content: TextField(controller: c, decoration: InputDecoration(hintText: tw('Жаңа құпиясөз', 'Новый пароль'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tw('Болдырмау', 'Отмена'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tw('Сақтау', 'Сохранить'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.changePassword(c.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tw('Сақталды', 'Сохранено'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
  }

  Future<void> _logout() async {
    Notifier.i.stop();
    await Api.i.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.me['user'] as Map<String, dynamic>;
    final cmp = widget.me['company'] as Map<String, dynamic>;
    final wa = '${widget.me['whatsapp'] ?? ''}';
    final img = Api.i.img('${u['img'] ?? ''}');
    final name = '${u['name']}'.trim();
    return Scaffold(
      appBar: AppBar(title: Text(tw('Аккаунт', 'Аккаунт'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: kGreen.withValues(alpha: .15),
                backgroundImage: img.isEmpty ? null : NetworkImage(img),
                child: img.isEmpty
                    ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kGreen))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(phoneFmt('${u['phone']}'), style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    if ('${u['position']}'.isNotEmpty) Chip(label: Text('${u['position']}'), visualDensity: VisualDensity.compact),
                    if ('${cmp['name']}'.isNotEmpty) Chip(label: Text('${cmp['name']}'), visualDensity: VisualDensity.compact),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.language, color: Colors.black54),
              const SizedBox(width: 10),
              Text(tw('Тіл', 'Язык')),
              const Spacer(),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'kz', label: Text('ҚАЗ')), ButtonSegment(value: 'ru', label: Text('РУС'))],
                selected: {Api.i.lang == 'ru' ? 'ru' : 'kz'},
                onSelectionChanged: (s) async {
                  await Api.i.setLang(s.first);
                  await widget.onLang();
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(tw('Бас тарту', 'Отказы')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(tw('Бас тарту', 'Отказы'))),
                  body: const OrdersList(sort: 'none'),
                ),
              )),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(tw('Курьерлер', 'Курьеры')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CouriersScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(tw('Құпиясөзді өзгерту', 'Сменить пароль')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _password,
            ),
            if (wa.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(tw('Көмек (WhatsApp)', 'Помощь (WhatsApp)')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openUrl('https://wa.me/$wa'),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(tw('Шығу', 'Выйти'), style: const TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('Berik POS · Раздача', style: TextStyle(color: Colors.black38))),
      ]),
    );
  }
}
