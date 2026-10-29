import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Сервер мекенжайы. Жинағанда өзгертуге болады:
/// flutter build apk --dart-define=API_URL=https://dist.example.kz
const String kDefaultServer = String.fromEnvironment('API_URL', defaultValue: 'https://dist.pf.kz');

class ApiError implements Exception {
  final String code;
  final int status;
  ApiError(this.code, [this.status = 0]);
  bool get isAuth => status == 401 || code == 'auth';
  @override
  String toString() => code;
}

/// dist.pf.c/api/ сұраулары
class Api {
  Api._();
  static final Api i = Api._();

  String server = kDefaultServer;
  String? token;
  String lang = 'kz';

  /// Компания қаласы (2GIS сілтемесі үшін), a=me-ден келеді
  String city = 'shymkent';

  /// Токен жарамсыз болса шақырылады (кіру бетіне қайтару үшін)
  void Function()? onLogout;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    server = p.getString('server') ?? kDefaultServer;
    token = p.getString('token');
    lang = p.getString('lang') ?? 'kz';
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('server', server);
    await p.setString('lang', lang);
    if (token == null) {
      await p.remove('token');
    } else {
      await p.setString('token', token!);
    }
  }

  Future<void> setLang(String l) async {
    lang = l;
    await _save();
  }

  Future<void> setServer(String s) async {
    s = s.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isNotEmpty && !s.startsWith('http')) s = 'https://$s';
    server = s.isEmpty ? kDefaultServer : s;
    await _save();
  }

  Future<void> logout() async {
    token = null;
    await _save();
  }

  Uri _uri(String a, [Map<String, String>? q]) =>
      Uri.parse('$server/api/').replace(queryParameters: {'a': a, ...?q});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Lang': lang,
        if (token != null) 'Authorization': 'Bearer $token',
        if (token != null) 'X-Token': token!,
      };

  Future<Map<String, dynamic>> _handle(http.Response r) async {
    Map<String, dynamic> d;
    try {
      d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiError('server', r.statusCode);
    }
    if (d['ok'] != true) {
      final e = ApiError('${d['error'] ?? 'error'}', r.statusCode);
      if (e.isAuth && token != null) {
        await logout();
        onLogout?.call();
      }
      throw e;
    }
    return d;
  }

  Future<Map<String, dynamic>> get(String a, [Map<String, String>? q]) async {
    try {
      final r = await http.get(_uri(a, q), headers: _headers).timeout(const Duration(seconds: 20));
      return await _handle(r);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('network');
    }
  }

  Future<Map<String, dynamic>> post(String a, Map<String, dynamic> body) async {
    try {
      final r = await http
          .post(_uri(a), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return await _handle(r);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('network');
    }
  }

  Future<void> login(String phone, String password) async {
    final d = await post('login', {'phone': phone, 'password': password});
    token = d['token'] as String;
    await _save();
  }

  Future<void> changePassword(String p) async {
    final d = await post('password', {'password': p});
    token = d['token'] as String;
    await _save();
  }

  String img(String path) => path.isEmpty ? '' : '$server$path';
}
