// The landing's roles page, generated from the game's own catalogue
// (lib/rules/role_catalog.dart) and the Italian narration pack (names,
// mottos, explanations). Re-run it whenever a role is added or reworded:
//
//   dart run tool/site/roles_page.dart
//
// It rewrites site/oberta/ruoli.html and the role list of the hold-to-reveal
// card in site/oberta/app.js (between the `roles:start` / `roles:end` marks).
// Icons are expected at site/oberta/img/roles/<id>.png; a missing icon is
// reported and the card falls back to the card back.
import 'dart:io';

import 'package:oberta/narration/italian_pack.dart';
import 'package:oberta/rules/game_engine.dart' show RoleDayPower;
import 'package:oberta/rules/role.dart';
import 'package:oberta/rules/role_catalog.dart';

const _site = 'site/oberta';

const _groups = <Team, (String, String, String, String)>{
  // title, card faction label, app.js key, intro
  Team.citizens: (
    'Villaggio',
    'La città',
    'citta',
    'Non sanno chi uccide. Indagano, proteggono, accusano: vincono quando gli assassini sono tutti fuori.',
  ),
  Team.mafia: (
    'Mafia',
    'La famiglia',
    'famiglia',
    'Si conoscono fra loro e ogni notte scelgono chi far sparire. Vincono quando sono tanti quanti tutti gli altri.',
  ),
  Team.neutral: (
    'Solitari',
    'Per sé',
    'neutrale',
    'Non stanno con nessuno. Ognuno ha la sua vittoria, e la cerca a spese di tutti.',
  ),
};

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// «Il Padrino» → «Padrino», «L'Onesto» → «Onesto».
String _bare(String label) => label.replaceFirst(RegExp(r"^(Il |Lo |La |I |Gli |Le |L')"), '');

/// 27 → «ventisette», 21 → «ventuno», 23 → «ventitré» (up to 99).
String _words(int n) {
  const units = ['', 'uno', 'due', 'tre', 'quattro', 'cinque', 'sei', 'sette', 'otto', 'nove'];
  const teens = ['dieci', 'undici', 'dodici', 'tredici', 'quattordici', 'quindici', 'sedici', 'diciassette', 'diciotto', 'diciannove'];
  const tens = ['', '', 'venti', 'trenta', 'quaranta', 'cinquanta', 'sessanta', 'settanta', 'ottanta', 'novanta'];
  if (n < 10) return units[n];
  if (n < 20) return teens[n - 10];
  final t = tens[n ~/ 10], u = n % 10;
  if (u == 0) return t;
  final head = (u == 1 || u == 8) ? t.substring(0, t.length - 1) : t;
  return '$head${u == 3 ? 'tré' : units[u]}';
}

String _facts(RoleCatalogEntry e) {
  final parts = <String>[
    if (e.minPlayers > 4) 'da ${e.minPlayers} giocatori',
    if (e.modes.length == 1 && e.modes.contains(PlayMode.online)) 'solo online',
    if (e.modes.length == 1 && e.modes.contains(PlayMode.sharedPhone)) 'solo su un telefono',
    // Al tavolo con un telefono solo i poteri di giorno passano da un bottone.
    if (e.role.dayPower != null && e.modes.contains(PlayMode.sharedPhone)) 'su un telefono: «Usa un potere»',
  ];
  return parts.join(' · ');
}

void main() {
  final missing = <String>[];
  final sections = StringBuffer();
  final byTeam = <List<String>>[];
  for (final MapEntry(key: team, value: (title, faction, key, intro)) in _groups.entries) {
    final entries = rolesOfTeam(team);
    if (entries.isEmpty) continue;
    final id = key;
    final cards = <String>[];
    byTeam.add(cards);
    sections.writeln('      <section class="roles-group roles-group--$key" id="$id" aria-labelledby="$id-title">');
    sections.writeln('        <header class="roles-group__head">');
    sections.writeln('          <h2 id="$id-title">${_esc(title)}</h2>');
    sections.writeln('          <p>${_esc(intro)}</p>');
    sections.writeln('          <span class="roles-group__count">${entries.length} ruoli</span>');
    sections.writeln('        </header>');
    sections.writeln('        <ul class="roles-grid">');
    for (final e in entries) {
      final text = italianPack.roles[e.role];
      if (text == null) {
        stderr.writeln('No Italian text for ${e.id}: skipped.');
        continue;
      }
      final icon = File('$_site/img/roles/${e.id}.png').existsSync() ? 'img/roles/${e.id}.png' : 'img/dorso.png';
      if (!icon.contains(e.id)) missing.add(e.id);
      final facts = _facts(e);
      sections
        ..writeln('          <li class="role" id="ruolo-${e.id}">')
        ..writeln('            <img class="role__icon" src="$icon" alt="" width="160" height="160" loading="lazy">')
        ..writeln('            <div class="role__text">')
        ..writeln('              <h3>${_esc(text.label)}</h3>')
        ..writeln('              <p class="role__motto">${_esc(text.motto)}</p>')
        ..writeln('              <p>${_esc(text.description)}</p>')
        ..writeln(facts.isEmpty ? '' : '              <p class="role__facts">${_esc(facts)}</p>')
        ..writeln('            </div>')
        ..writeln('          </li>');
      cards.add("['${e.id}', '${_bare(text.label).replaceAll("'", r"\'")}', '$faction', '$key']");
    }
    sections.writeln('        </ul>');
    sections.writeln('      </section>');
  }

  final total = roleCatalog.length;
  final html = '''<!doctype html>
<html lang="it">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#a51d25">
    <meta name="description" content="Tutti i $total ruoli di Obertà: il Villaggio, la Mafia e i Solitari, con il motto e cosa fa ognuno.">
    <title>Obertà — I ruoli</title>
    <link rel="icon" href="favicon.png" type="image/png">
    <link rel="apple-touch-icon" href="apple-touch-icon.png">
    <link rel="stylesheet" href="style.css">
  </head>
  <body class="roles-page">
    <!-- Generated by tool/site/roles_page.dart from the game's role catalogue: do not edit by hand. -->
    <a class="skip-link" href="#contenuto">Vai al contenuto</a>
    <header class="site-header">
      <a class="wordmark" href="./" aria-label="Obertà, inizio">OBERTÀ<span>®</span></a>
      <nav aria-label="Navigazione principale">
        <a href="./#amici">Come si gioca</a>
        <a href="ruoli.html" aria-current="page">I ruoli</a>
        <a href="./#piattaforme">Dove si gioca</a>
      </nav>
      <a class="header-cta" href="./">Torna al quartiere <span aria-hidden="true">↖</span></a>
    </header>
    <main id="contenuto">
      <section class="roles-hero" aria-labelledby="roles-title">
        <figure class="roles-hero__shot" data-ui>
          <img src="img/collezione.jpg" alt="La collezione dei ruoli nel gioco: le carte già vinte scoperte, le altre coperte col lucchetto" width="600" height="1300">
          <figcaption>Nel gioco: le carte da scoprire.</figcaption>
        </figure>
        <div class="roles-hero__copy">
          <h1 id="roles-title">I ruoli.</h1>
          <p>$total carte, tre parti. Una a testa, e non si fa vedere. Più siete al tavolo (da 4 a 12), più ruoli entrano. Nel gioco ogni carta resta coperta finché non ci vinci una partita.</p>
          <nav class="roles-jump" aria-label="Le tre parti">
${[for (final MapEntry(value: (title, _, key, _)) in _groups.entries) '            <a href="#$key">${_esc(title)}</a>'].join('\n')}
          </nav>
        </div>
      </section>
$sections    </main>
    <footer class="site-footer">
      <a class="wordmark wordmark--footer" href="./">OBERTÀ<span>®</span></a>
      <p>Chi sa, tace. Chi parla non vede l’alba.</p>
      <a class="footer-top" href="#contenuto">Torna su <span aria-hidden="true">↑</span></a>
      <nav class="footer-links" aria-label="Informazioni">
        <a href="mailto:oberta@charliemobile.dev">Contatti</a>
        <a href="privacy.html">Privacy</a>
        <a href="termini.html">Termini</a>
      </nav>
      <small>© 2026 Obertà · Nicolai Tana · charliemobile.dev</small>
    </footer>
  </body>
</html>
''';
  File('$_site/ruoli.html').writeAsStringSync(html.replaceAllMapped(RegExp(r'\n\s*\n(\s*</div>)'), (m) => '\n${m[1]}'));

  // The hold-to-reveal card on the home page cycles through every role,
  // taking turns between the three sides so it never shows five in a row.
  final cards = <String>[
    for (var i = 0; i < byTeam.fold(0, (n, l) => l.length > n ? l.length : n); i++)
      for (final list in byTeam)
        if (i < list.length) list[i],
  ];
  final app = File('$_site/app.js');
  final js = app.readAsStringSync();
  final block = RegExp(r'// roles:start\n[\s\S]*?// roles:end');
  if (block.hasMatch(js)) {
    final rows = [for (var i = 0; i < cards.length; i += 3) '  ${cards.skip(i).take(3).join(', ')}'].join(',\n');
    app.writeAsStringSync(js.replaceFirst(block, '// roles:start\nconst roles = [\n$rows\n];\n// roles:end'));
  } else {
    stderr.writeln('app.js has no roles:start/roles:end block: card list left alone.');
  }

  // The roles section of the home page: just the count, as its title.
  final index = File('$_site/index.html');
  final page = index.readAsStringSync();
  final summary = RegExp(r'(<!-- roles:summary[^>]*-->\n)[\s\S]*?(\s*<!-- roles:summary:end -->)');
  if (summary.hasMatch(page)) {
    final count = _words(total);
    final text = '          <h2 id="ruoli-title">${count[0].toUpperCase()}${count.substring(1)} ruoli.</h2>';
    index.writeAsStringSync(page.replaceFirstMapped(summary, (m) => '${m[1]}$text${m[2]}'));
  } else {
    stderr.writeln('index.html has no roles:summary block: roles title left alone.');
  }

  stdout.writeln('ruoli.html: $total roles (${[for (final t in Team.values) '${t.name} ${rolesOfTeam(t).length}'].join(', ')}).');
  if (missing.isNotEmpty) stderr.writeln('Missing icons in $_site/img/roles/: ${missing.join(', ')}');
}
