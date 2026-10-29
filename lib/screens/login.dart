import 'package:flutter/material.dart';

import '../api.dart';
import '../main.dart';
import '../t.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _err;

  Future<void> _login() async {
    final ph = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (ph.length < 10 || _pass.text.isEmpty) {
      setState(() => _err = errText('wrong'));
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Api.i.login(ph, _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _err = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _serverDialog() async {
    final c = TextEditingController(text: Api.i.server);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tw('Сервер', 'Сервер')),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'https://dist.example.kz'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tw('Болдырмау', 'Отмена'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tw('Сақтау', 'Сохранить'))),
        ],
      ),
    );
    if (ok == true) {
      await Api.i.setServer(c.text);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/icon.png', width: 72, height: 72),
                  const SizedBox(height: 12),
                  const Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'BERIK '),
                      TextSpan(text: 'POS', style: TextStyle(color: kGreen)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 6),
                  Text(tw('Раздача', 'Раздача'),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_iphone), hintText: '8 (700) 000-00-00'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: tw('Құпиясөз', 'Пароль'),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(tw('Кіру', 'Вход'), style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final l in const ['kz', 'ru'])
                        TextButton(
                          onPressed: () async {
                            await Api.i.setLang(l);
                            setState(() {});
                          },
                          child: Text(l == 'kz' ? 'ҚАЗ' : 'РУС',
                              style: TextStyle(fontWeight: Api.i.lang == l ? FontWeight.w800 : FontWeight.w400)),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _serverDialog,
                    icon: const Icon(Icons.dns_outlined, size: 18, color: Colors.grey),
                    label: Text(Api.i.server.replaceFirst(RegExp(r'^https?://'), ''),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
