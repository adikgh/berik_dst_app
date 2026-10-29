import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 't.dart';

/// Жаңа тапсырыс түскенін тексереді: әр 15 секундта /api/?a=poll.
/// Саны өссе, стандарт дыбыспен хабарлама шығады.
/// (Программа толық жабық тұрғанда хабарлама келуі үшін кейін Firebase push қосылады.)
class Notifier {
  Notifier._();
  static final Notifier i = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  int _lastId = -1;
  Map<String, int> counts = {};

  /// Тапсырыстар өзгерген сайын өседі: тізімдер осыны көріп қайта жүктеледі
  int version = 0;
  final _listeners = <void Function()>[];
  bool _busy = false;

  void addListener(void Function() f) => _listeners.add(f);
  void removeListener(void Function() f) => _listeners.remove(f);

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void start() {
    _timer?.cancel();
    _lastId = -1;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy || Api.i.token == null) return;
    _busy = true;
    try {
      final d = await Api.i.get('poll');
      final last = (d['last_id'] as num?)?.toInt() ?? 0;
      final c = <String, int>{};
      (d['counts'] as Map? ?? {}).forEach((k, v) => c['$k'] = (v as num).toInt());
      final grew = c.entries.any((e) => e.value > (counts[e.key] ?? 0));
      if (_lastId >= 0 && last > _lastId && grew) await _show();
      if (last != _lastId || c.toString() != counts.toString()) version++;
      _lastId = last;
      counts = c;
      for (final f in List.of(_listeners)) {
        f();
      }
    } catch (_) {
      // желі уақытша жоқ: келесі жолы қайта тексереді
    } finally {
      _busy = false;
    }
  }

  Future<void> _show() async {
    const android = AndroidNotificationDetails(
      'new_orders',
      'Жаңа тапсырыстар',
      channelDescription: 'Жаңа тапсырыс түскенде',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true);
    await _plugin.show(
      1,
      tw('Жаңа тапсырыс', 'Новый заказ'),
      tw('Раздачаға жаңа тапсырыс түсті', 'Поступил новый заказ'),
      const NotificationDetails(android: android, iOS: ios),
    );
  }
}
