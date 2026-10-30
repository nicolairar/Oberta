import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../street/street_facade.dart';
import '../street/street_neon.dart';
import '../street/street_route.dart';
import '../street/street_section.dart';
import '../street/street_stage.dart';
import '../street/street_wall.dart';
import '../widgets/baked.dart';
import '../widgets/home_alley.dart';
import '../widgets/home_neon_sign.dart';

part 'season_paint.dart';
part 'natale.dart';
part 'halloween.dart';

/// Le feste dell'anno che il vicolo, la strada e il tavolo sanno festeggiare.
enum Season { natale, halloween, carnevale, pasqua }

/// Una delle prove di una festa: per ogni festa se ne disegnano alcune, il
/// proprietario ne sceglie una ([SeasonLooks.picked]).
abstract interface class SeasonLook {
  Season get season;

  /// Il suo nome, «natale.cenone»: quello da scrivere in `--dart-define=SEASON=`.
  String get key;
}

// ------------------------------------------------------------ il calendario

/// I giorni di una festa in un anno: il primo e l'ultimo, compresi (l'ultimo
/// può cadere l'anno dopo, come l'Epifania per il Natale).
sealed class SeasonDays {
  const SeasonDays();

  (DateTime, DateTime) inYear(int year);
}

/// Una festa a date fisse: dal [fromDay] di [fromMonth] al [toDay] di [toMonth].
class FixedDays extends SeasonDays {
  final int fromMonth, fromDay, toMonth, toDay;

  const FixedDays(this.fromMonth, this.fromDay, this.toMonth, this.toDay);

  @override
  (DateTime, DateTime) inYear(int year) {
    final from = DateTime(year, fromMonth, fromDay);
    final to = DateTime(year, toMonth, toDay);
    return (from, to.isBefore(from) ? DateTime(year + 1, toMonth, toDay) : to);
  }
}

/// Una festa mobile, contata dalla domenica di Pasqua: [from] e [to] sono i
/// giorni prima (negativi) o dopo.
class EasterDays extends SeasonDays {
  final int from, to;

  const EasterDays(this.from, this.to);

  @override
  (DateTime, DateTime) inYear(int year) {
    final easter = SeasonCalendar.easter(year);
    return (DateTime(year, easter.month, easter.day + from), DateTime(year, easter.month, easter.day + to));
  }
}

@immutable
class SeasonWindow {
  final Season season;
  final SeasonDays days;

  const SeasonWindow(this.season, this.days);

  /// Il giorno [day] cade in questa festa (di quest'anno o di quella iniziata l'anno prima).
  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    for (final year in [d.year - 1, d.year]) {
      final (from, to) = days.inYear(year);
      if (!d.isBefore(from) && !d.isAfter(to)) return true;
    }
    return false;
  }
}

/// Le feste, una riga ciascuna: per aggiungerne una basta una riga qui (e le
/// sue prove). Se due si sovrappongono vince la prima della lista: ce n'è
/// sempre una sola alla volta.
abstract final class SeasonCalendar {
  static const windows = [
    // Halloween, Ognissanti e i Morti.
    SeasonWindow(Season.halloween, FixedDays(10, 24, 11, 2)),
    // Dall'Avvento all'Epifania.
    SeasonWindow(Season.natale, FixedDays(12, 1, 1, 6)),
    // Dal giovedì al martedì grasso.
    SeasonWindow(Season.carnevale, EasterDays(-52, -47)),
    // Dal giovedì santo a Pasquetta.
    SeasonWindow(Season.pasqua, EasterDays(-3, 1)),
  ];

  /// La festa di [day], se ce n'è una.
  static Season? on(DateTime day) {
    for (final window in windows) {
      if (window.covers(day)) return window.season;
    }
    return null;
  }

  /// La domenica di Pasqua di [year] (calendario gregoriano, l'algoritmo
  /// anonimo di Meeus/Jones/Butcher).
  static DateTime easter(int year) {
    final a = year % 19, b = year ~/ 100, c = year % 100;
    final d = b ~/ 4, e = b % 4, f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4, k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final n = h + l - 7 * m + 114;
    return DateTime(year, n ~/ 31, n % 31 + 1);
  }
}

/// Quale prova si vede, e quando.
abstract final class SeasonLooks {
  /// La prova scelta per ogni festa: senza una riga qui la festa non si
  /// accende per chi gioca, anche quando il calendario dice che è il suo giorno.
  static const Map<Season, SeasonLook> picked = {
    Season.natale: NataleLook.cenone,
    Season.halloween: HalloweenLook.nebbia,
  };

  static List<SeasonLook> get all => [...NataleLook.values, ...HalloweenLook.values];

  /// Per provare: una prova forzata, qualunque sia il giorno (null: il
  /// calendario). Si può forzare anche da fuori, in una build di prova:
  /// `--dart-define=SEASON=halloween.morti` (o solo `halloween`, per la
  /// prova scelta o la prima).
  static SeasonLook? debugOverride;

  /// I test non devono cambiare col giorno in cui girano: niente calendario,
  /// si accende solo quello che si forza.
  static bool debugCalendarOff = false;

  static const _forced = String.fromEnvironment('SEASON');

  /// La prova di nome [name] («natale.cenone»), o quella di una festa («natale»).
  static SeasonLook? named(String name) {
    for (final look in all) {
      if (look.key == name) return look;
    }
    for (final season in Season.values) {
      if (season.name != name) continue;
      return picked[season] ?? all.where((look) => look.season == season).firstOrNull;
    }
    return null;
  }

  /// La prova da mostrare il giorno [now].
  static SeasonLook? at(DateTime now) {
    if (debugOverride case final look?) return look;
    if (_forced.isNotEmpty) return named(_forced);
    if (debugCalendarOff) return null;
    final season = SeasonCalendar.on(now);
    return season == null ? null : picked[season];
  }

  static (int, int, int)? _day;
  static SeasonLook? _today;

  /// La prova di oggi, ricalcolata una volta al giorno.
  static SeasonLook? get today {
    if (debugOverride != null || _forced.isNotEmpty) return at(DateTime.now());
    if (debugCalendarOff) return null;
    final now = DateTime.now();
    final day = (now.year, now.month, now.day);
    if (day != _day) {
      _day = day;
      _today = at(now);
    }
    return _today;
  }
}

/// La festa accesa sotto [child], qualunque sia il giorno (null: nessuna).
/// Senza uno scope sopra di sé ogni schermata chiede a [SeasonLooks.today].
class SeasonScope extends InheritedWidget {
  final SeasonLook? look;

  const SeasonScope({super.key, required this.look, required super.child});

  static SeasonLook? of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SeasonScope>();
    return scope == null ? SeasonLooks.today : scope.look;
  }

  @override
  bool updateShouldNotify(SeasonScope old) => old.look != look;
}

// ------------------------------------------------------------ i ganci

/// La festa nel vicolo di casa: le sue luci, che si mescolano a quelle del
/// muro, e gli strati da mettere tra quelli della schermata, dal muro in su.
abstract interface class SeasonAlley {
  List<StreetLight> get lights;

  /// Se piove ancora (la neve, per dire, prende il suo posto).
  bool get rain;

  /// Sul muro, sotto l'insegna e i manifesti.
  Widget? get wall;

  /// Sulle lettere di OBERTÀ (scivola via con l'insegna).
  Widget? get letters;

  /// Sui manifesti (scivola via con loro).
  Widget? get posters;

  /// Davanti ai manifesti, dietro il lampione e l'uomo.
  Widget? get front;

  /// Sopra a tutto, tranne la didascalia.
  Widget? top(Animation<double> intro);

  /// Quella di oggi (o dello scope), per un vicolo di misure [layout].
  static SeasonAlley? of(BuildContext context, HomeAlleyLayout layout, {required bool desktop, required bool canvas, required bool signedIn}) =>
      switch (SeasonScope.of(context)) {
        final NataleLook look => NataleAlley(look, layout, desktop: desktop, canvas: canvas, signedIn: signedIn),
        final HalloweenLook look => HalloweenAlley(look, layout, desktop: desktop, canvas: canvas, signedIn: signedIn),
        _ => null,
      };
}

/// La festa davanti a un locale della strada.
abstract interface class SeasonStreet {
  List<StreetLight> get lights;

  /// Sotto la facciata: a terra e sul muro.
  Widget? get ground;

  /// Sopra la facciata ([door]: quanto è aperta la porta; [vignette]: la
  /// vignettatura, che la facciata allora lascia a lei).
  Widget? front({required double door, required bool vignette});

  /// Nell'aria, davanti all'insegna e dietro i pannelli.
  Widget? get air;

  static SeasonStreet? of(BuildContext context, StreetFacadeLayout layout, StreetSection section, {required int index, List<StreetLight> before = const []}) =>
      switch (SeasonScope.of(context)) {
        final NataleLook look => NataleStreet(look, layout, section, index: index, before: before),
        final HalloweenLook look => HalloweenStreet(look, layout, section, index: index, before: before),
        _ => null,
      };
}

/// La festa nella sala sul retro e sul tavolo.
abstract final class SeasonTable {
  /// Sulle pareti e sul pavimento, sotto il tavolo.
  static Widget? room(BuildContext context, {required bool night}) => switch (SeasonScope.of(context)) {
    final NataleLook look => _nataleRoom(look, night: night),
    final HalloweenLook look => _halloweenRoom(look, night: night),
    _ => null,
  };

  /// Sul panno e sul bordo, sotto i posti.
  static Widget? felt(BuildContext context, {required Rect felt, required List<Offset> centers, required double card, required Rect area}) =>
      switch (SeasonScope.of(context)) {
        final NataleLook look => _nataleFelt(look, felt: felt, centers: centers, card: card, area: area),
        final HalloweenLook look => _halloweenFelt(look, felt: felt, centers: centers, card: card, area: area),
        _ => null,
      };

  /// Sulle targhette dei posti.
  static Widget? seats(BuildContext context, {required List<Offset> centers, required double card}) => switch (SeasonScope.of(context)) {
    final NataleLook look => _nataleSeats(look, centers: centers, card: card),
    final HalloweenLook look => _halloweenSeats(look, centers: centers, card: card),
    _ => null,
  };
}
