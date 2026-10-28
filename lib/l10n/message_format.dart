import 'package:intl/intl.dart' show Intl;

/// Fills a message template, in the spirit of ICU MessageFormat but without
/// its apostrophe quoting (Italian and French are full of apostrophes):
///
/// - `{name}` is replaced by the argument `name`;
/// - `{n, plural, =0{none} one{# game} other{# games}}` picks the plural
///   form of the language (`zero`, `one`, `two`, `few`, `many`, `other`, or
///   an exact `=N`), and `#` inside it is the number;
/// - `{g, select, feminine{...} masculine{...} other{...}}` picks by value.
///
/// Forms nest. An unknown argument stays as `{name}`, so a missing value is
/// visible instead of silently empty.
String formatMessage(String template, Map<String, Object?> args, {String locale = 'en'}) {
  if (!template.contains('{')) return template;
  return _Formatter(template, args, locale).run();
}

/// The placeholder names a template uses, plural and select included.
Set<String> messagePlaceholders(String template) {
  final names = <String>{};
  final word = RegExp(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*([,}])');
  final selector = RegExp(r'\s*([^\s{}]+)\s*\{');
  // Reads text from [i] to the brace closing its form; returns where it stopped.
  int text(int i) {
    while (i < template.length) {
      final c = template[i];
      if (c == '}') return i;
      if (c == '{') {
        final m = word.matchAsPrefix(template, i);
        if (m == null) {
          i++;
          continue;
        }
        names.add(m.group(1)!);
        i = m.end;
        if (m.group(2) == '}') continue;
        // `{name, kind, sel{...} sel{...}}`
        final comma = template.indexOf(',', i);
        if (comma < 0) return template.length;
        i = comma + 1;
        while (true) {
          final s = selector.matchAsPrefix(template, i);
          if (s == null) break;
          i = text(s.end);
          if (i < template.length) i++; // the form's closing brace
        }
        while (i < template.length && template[i] != '}') {
          i++;
        }
        i++; // the placeholder's closing brace
        continue;
      }
      i++;
    }
    return i;
  }

  text(0);
  return names;
}

class _Formatter {
  final String source;
  final Map<String, Object?> args;
  final String locale;
  int i = 0;

  _Formatter(this.source, this.args, this.locale);

  String run() => _text(null, null);

  /// Reads text up to the closing brace of the enclosing form (or the end).
  /// [number] is what `#` stands for inside a plural form.
  String _text(num? number, String? numberText) {
    final out = StringBuffer();
    while (i < source.length) {
      final c = source[i];
      if (c == '}') return out.toString();
      if (c == '#' && number != null) {
        out.write(numberText);
        i++;
        continue;
      }
      if (c == '{') {
        final start = i;
        final placeholder = _placeholder(number, numberText);
        out.write(placeholder ?? source.substring(start, i));
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  /// Parses `{...}` at [i]. Returns null when it is not a placeholder, and
  /// leaves [i] just past what was read.
  String? _placeholder(num? number, String? numberText) {
    final open = i;
    i++;
    final name = _word();
    if (name.isEmpty) {
      i = open + 1;
      return null;
    }
    _spaces();
    if (i < source.length && source[i] == '}') {
      i++;
      if (!args.containsKey(name)) return '{$name}';
      return '${args[name]}';
    }
    if (i >= source.length || source[i] != ',') {
      i = open + 1;
      return null;
    }
    i++;
    _spaces();
    final kind = _word();
    _spaces();
    if (i >= source.length || source[i] != ',') {
      i = open + 1;
      return null;
    }
    i++;
    final forms = <String, String>{};
    final value = args[name];
    final n = value is num ? value : num.tryParse('$value');
    while (true) {
      _spaces();
      if (i >= source.length) break;
      if (source[i] == '}') {
        i++;
        break;
      }
      final selector = _selector();
      _spaces();
      if (i >= source.length || source[i] != '{') break;
      i++;
      final body = kind == 'plural' ? _text(n, n == null ? '$value' : _numberText(n)) : _text(number, numberText);
      if (i < source.length && source[i] == '}') i++;
      forms[selector] = body;
    }
    if (kind == 'plural') {
      if (n == null) return forms['other'] ?? '';
      final exact = forms['=${n is int ? n : n.toInt()}'];
      if (exact != null && n == n.toInt()) return exact;
      final category = _pluralCategory(n);
      return forms[category] ?? forms['other'] ?? '';
    }
    return forms['$value'] ?? forms['other'] ?? '';
  }

  String _numberText(num n) => n == n.toInt() ? '${n.toInt()}' : '$n';

  String _pluralCategory(num n) {
    try {
      return Intl.pluralLogic<String>(
        n,
        locale: locale,
        useExplicitNumberCases: false,
        zero: 'zero',
        one: 'one',
        two: 'two',
        few: 'few',
        many: 'many',
        other: 'other',
      );
    } catch (_) {
      return n == 1 ? 'one' : 'other';
    }
  }

  String _word() {
    final start = i;
    while (i < source.length && RegExp(r'[A-Za-z0-9_]').hasMatch(source[i])) {
      i++;
    }
    return source.substring(start, i);
  }

  String _selector() {
    final start = i;
    while (i < source.length && !RegExp(r'[\s{}]').hasMatch(source[i])) {
      i++;
    }
    return source.substring(start, i);
  }

  void _spaces() {
    while (i < source.length && source[i].trim().isEmpty) {
      i++;
    }
  }
}
