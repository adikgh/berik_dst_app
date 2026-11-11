import 'package:flutter/services.dart';
import 'api.dart';

/// Программа мәтіндері: қазақша (стандарт) және орысша, сайттағы t::w('kz', 'ru') сияқты.
/// Тапсырыс статустары мен төлем атаулары серверден таңдалған тілде келеді.
String tw(String kz, String ru) => Api.i.lang == 'ru' ? ru : kz;

String money(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b ₸';
}

String phoneFmt(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length != 10) return p;
  return '8 (${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6, 8)}-${d.substring(8)}';
}

/// Телефон маскасы 8 (700) 000-00-00, Berik сайттарындағыдай. Серверге соңғы 10 сан барады.
class PhoneMask extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('8') || (d.startsWith('7') && d.length > 10)) d = d.substring(1);
    if (d.length > 10) d = d.substring(0, 10);
    var o = '';
    if (d.isNotEmpty) o = '8 (${d.substring(0, d.length < 3 ? d.length : 3)}';
    if (d.length >= 3) o += ') ${d.substring(3, d.length < 6 ? d.length : 6)}';
    if (d.length >= 6) o += '-${d.substring(6, d.length < 8 ? d.length : 8)}';
    if (d.length >= 8) o += '-${d.substring(8)}';
    return TextEditingValue(text: o, selection: TextSelection.collapsed(offset: o.length));
  }
}

/// Маскадағы нөмірдің соңғы 10 саны
String phone10(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

String errText(Object e) {
  final c = e.toString();
  switch (c) {
    case 'wrong':
      return tw('Нөмір не құпиясөз қате', 'Неверный номер или пароль');
    case 'no_access':
      return tw('Раздачаға рұқсат жоқ', 'Нет доступа к раздаче');
    case 'network':
      return tw('Интернет не сервер жоқ', 'Нет интернета или сервера');
    case 'locked':
      return tw('Бұл тапсырысты енді өзгертуге болмайды', 'Этот заказ уже нельзя изменить');
    case 'phone':
      return tw('Нөмір 10 саннан тұруы керек', 'Номер должен быть из 10 цифр');
    case 'phone_busy':
      return tw('Бұл нөмір басқа адамда тіркелген', 'Номер уже занят');
    case 'short':
      return tw('Құпиясөз тым қысқа', 'Пароль слишком короткий');
    case 'company_expired':
      return tw('Компанияның төлем мерзімі бітті', 'Срок оплаты компании истёк');
    default:
      return '${tw('Қате шықты', 'Произошла ошибка')} ($c)';
  }
}
