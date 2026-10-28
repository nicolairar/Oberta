// Chat demos for the online game, before anything changes in the live
// screen: a denser, more readable log with the seat number up front, phase
// separators and system events inline, channel tabs with unread badges, a
// compact "roles in play" strip, and seats that read at a glance.
//
// Everything here is mock data drawn with the live widgets (SeatCard,
// RoleIcon, TargaButton, PlayerAvatar). Nothing in lib/ depends on it.
import 'package:flutter/material.dart';
import 'package:oberta/l10n/app_strings.dart';
import 'package:oberta/rules/role.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/theme/role_style.dart';
import 'package:oberta/ui/widgets/targa.dart';

// ---------------------------------------------------------------------------
// Mock game: 12 players, day 2, the vote is open. I am seat 2, Bruno, in
// the family with 7 Gina and 11 Nora.

class DemoSeat {
  final int n;
  final String name;
  final bool dead;
  final Role? shown;
  final int votes;
  final int? votesFor;
  final bool family;

  const DemoSeat(this.n, this.name, {this.dead = false, this.shown, this.votes = 0, this.votesFor, this.family = false});
}

const me = 2;

const seats = [
  DemoSeat(1, 'Anna', votesFor: 4),
  DemoSeat(2, 'Bruno', votesFor: 4, family: true),
  DemoSeat(3, 'Carmela', votesFor: 10),
  DemoSeat(4, 'Dario', votes: 4, votesFor: 10),
  DemoSeat(5, 'Elena', shown: Role.sindaco, votesFor: 4),
  DemoSeat(6, 'Fausto', dead: true, shown: Role.medico),
  DemoSeat(7, 'Gina', family: true),
  DemoSeat(8, 'Ignazio', votesFor: 4),
  DemoSeat(9, 'Lucia', dead: true, shown: Role.cittadino),
  DemoSeat(10, 'Marco', votes: 2),
  DemoSeat(11, 'Nora', family: true),
  DemoSeat(12, 'Totò'),
];

DemoSeat seat(int n) => seats[n - 1];

/// The roles dealt in this game, and how many of each.
const deck = <Role, int>{
  Role.mafioso: 2,
  Role.padrino: 1,
  Role.detective: 1,
  Role.medico: 1,
  Role.cecchino: 1,
  Role.giornalista: 1,
  Role.sindaco: 1,
  Role.cittadino: 3,
  Role.fesso: 1,
};

/// Revealed dead, by role.
const gone = <Role, int>{Role.medico: 1, Role.cittadino: 1};

/// A name colour per seat: warm, muted, all readable on ink.
const _hues = [
  Color(0xFFE8B86B),
  Color(0xFF9FC7E8),
  Color(0xFFE59A8C),
  Color(0xFFA8D69A),
  Color(0xFFD6A6E0),
  Color(0xFFB8B0A6),
  Color(0xFF8FD6CC),
  Color(0xFFF0D27A),
  Color(0xFFB8B0A6),
  Color(0xFFEFA0B8),
  Color(0xFFC7C28A),
  Color(0xFF9CB6F0),
];

Color hueOf(int n) => _hues[(n - 1) % _hues.length];

sealed class Entry {
  const Entry();
}

class PhaseEntry extends Entry {
  final String label;
  final bool night;
  final String? note;
  const PhaseEntry(this.label, {this.night = false, this.note});
}

enum Tone { kill, vote, info, quiet }

/// A line of the server. Ints in [parts] are seat chips.
class EventEntry extends Entry {
  final Tone tone;
  final List<Object> parts;
  const EventEntry(this.tone, this.parts);
}

class Said extends Entry {
  final int n;
  final String body;

  /// Last words of the lynched, a revealed Mayor: the line is tinted.
  final bool lastWords;
  const Said(this.n, this.body, {this.lastWords = false});
}

const dayLog = <Entry>[
  PhaseEntry('Notte 1', night: true),
  EventEntry(Tone.kill, ['All\'alba trovano ', 6, ' morto. Era il ', 'Medico', '.']),
  PhaseEntry('Giorno 1', note: 'si discute'),
  Said(3, 'Fausto era il medico... adesso nessuno ci protegge.'),
  Said(8, 'Chi parla per primo di solito sa qualcosa.'),
  Said(9, 'Io sono cittadina, giuro. Guardate 10.'),
  Said(10, 'Io? Ho votato per ultimo ieri, che c\'entro.'),
  Said(1, 'Lucia accusa troppo in fretta.'),
  PhaseEntry('Si vota!', note: '6 voti necessari'),
  EventEntry(Tone.vote, [9, ' giustiziata con 7 voti. Era una ', 'Cittadina', '.']),
  Said(9, 'Avete sbagliato. Il marcio sta tra 4 e 10.', lastWords: true),
  PhaseEntry('Notte 2', night: true),
  EventEntry(Tone.quiet, ['Stanotte nessuno è morto.']),
  PhaseEntry('Giorno 2', note: 'si discute'),
  EventEntry(Tone.info, [5, ' si rivela ', 'Sindaco', ': il suo voto vale doppio.']),
  Said(5, 'Il mio voto pesa. Ascoltate bene prima di alzare la mano.'),
  Said(4, 'Nessun morto: il medico è morto, quindi qualcuno ha protetto. Chi?'),
  Said(12, 'O la famiglia ha mancato il colpo apposta.'),
  Said(3, '2 Bruno, ieri non hai detto una parola. Perché?'),
  Said(2, 'Ascoltavo. 4 Dario cambia storia ogni giro.'),
  Said(4, 'Ma per favore. 10 ha difeso Lucia e poi l\'ha votata.'),
  Said(10, 'Ho votato con la piazza, come tutti.'),
  Said(1, 'Concordo con Bruno, Dario mi puzza.'),
  Said(8, 'Io voto 4, non ho altri nomi.'),
  PhaseEntry('Si vota!', note: '6 voti necessari'),
  EventEntry(Tone.vote, [1, ' accusa ', 4]),
  EventEntry(Tone.vote, [2, ' accusa ', 4]),
  EventEntry(Tone.vote, [3, ' accusa ', 10]),
  EventEntry(Tone.vote, [5, ' accusa ', 4, ' (vale 2)']),
  Said(4, 'State sbagliando tutto, ve ne pentirete.'),
  EventEntry(Tone.vote, [8, ' accusa ', 4]),
  Said(12, 'Ci penso ancora un attimo.'),
];

const familyLog = <Entry>[
  PhaseEntry('Notte 2', night: true),
  Said(7, 'Stanotte niente colpi a caso: il cecchino è ancora vivo.'),
  Said(11, 'Proviamo 3, fa troppe domande.'),
  Said(2, 'Ok per 3.'),
  EventEntry(Tone.quiet, ['Il colpo su ', 3, ' non è andato: qualcuno l\'ha protetta.']),
  PhaseEntry('Giorno 2', note: 'solo voi tre'),
  Said(7, 'Spingete su Dario, ci sta cascando.'),
  Said(11, 'Io resto zitta, non voglio sembrare d\'accordo con voi.'),
  Said(7, 'Bruno, tienti lontano da 10: lui è pulito.'),
];

// ---------------------------------------------------------------------------
// Sizes: one set for the 1080p desk, one for the phone.

class ChatScale {
  final double font;
  final double chip;
  final double gap;
  final double phase;
  const ChatScale({required this.font, required this.chip, required this.gap, required this.phase});

  static const desk = ChatScale(font: 18, chip: 28, gap: 3, phase: 14);
  static const phone = ChatScale(font: 14, chip: 20, gap: 2, phase: 11);
}

// ---------------------------------------------------------------------------
// The pieces.

/// The seat number: a brass plate, always the same width, so the names
/// line up and the number is the first thing the eye catches.
class SeatChip extends StatelessWidget {
  final int n;
  final double size;
  final bool faded;
  const SeatChip(this.n, {super.key, required this.size, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final isMe = n == me;
    return Container(
      width: size * 1.15,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: faded ? const [Color(0xFF6E6862), Color(0xFF3E3935)] : const [Color(0xFFF2D58A), Saloon.brassDeep],
        ),
        border: Border.all(color: isMe ? Colors.white : const Color(0xFF1A120C), width: isMe ? 1.4 : 1),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: size * 0.66,
          fontWeight: FontWeight.w800,
          height: 1,
          color: const Color(0xFF1A120C),
        ),
      ),
    );
  }
}

InlineSpan _chipSpan(int n, ChatScale s, {bool withName = true}) {
  final d = seat(n);
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: s.font * 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeatChip(n, size: s.chip * 0.88, faded: d.dead),
          if (withName) ...[
            SizedBox(width: s.font * 0.25),
            Text(
              d.name,
              style: TextStyle(color: hueOf(n), fontWeight: FontWeight.w800, fontSize: s.font * 0.95),
            ),
          ],
        ],
      ),
    ),
  );
}

/// "Giorno 2 · si discute": a rule across the log with the phase in caps.
class PhaseRule extends StatelessWidget {
  final PhaseEntry e;
  final ChatScale s;

  /// Variant B: a filled band instead of a thin rule.
  final bool band;
  const PhaseRule(this.e, this.s, {super.key, this.band = false});

  @override
  Widget build(BuildContext context) {
    final vote = e.label.startsWith('Si vota');
    final color = vote ? Saloon.blood : (e.night ? const Color(0xFF8FA8D6) : Saloon.brass);
    final icon = vote ? Icons.how_to_vote : (e.night ? Icons.nightlight_round : Icons.wb_sunny);
    final label = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: e.label.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: s.phase * 0.18),
          ),
          if (e.note != null)
            TextSpan(
              text: '  ·  ${e.note}',
              style: TextStyle(color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
        ],
      ),
      style: TextStyle(fontSize: s.phase, height: 1.2),
    );
    if (band) {
      return Container(
        margin: EdgeInsets.only(top: s.gap * 4, bottom: s.gap * 2),
        padding: EdgeInsets.symmetric(horizontal: s.font * 0.6, vertical: s.font * 0.3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          border: Border(
            left: BorderSide(color: color, width: 4),
            bottom: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: s.phase * 1.3, color: color),
            SizedBox(width: s.font * 0.4),
            Expanded(child: label),
          ],
        ),
      );
    }
    final line = Expanded(child: Container(height: 1.2, color: color.withValues(alpha: 0.45)));
    return Padding(
      padding: EdgeInsets.only(top: s.gap * 5, bottom: s.gap * 2.5),
      child: Row(
        children: [
          line,
          SizedBox(width: s.font * 0.5),
          Icon(icon, size: s.phase * 1.25, color: color),
          SizedBox(width: s.font * 0.35),
          label,
          SizedBox(width: s.font * 0.5),
          line,
        ],
      ),
    );
  }
}

/// A line of the server, in the accent of what happened.
class EventLine extends StatelessWidget {
  final EventEntry e;
  final ChatScale s;
  final bool boxed;
  const EventLine(this.e, this.s, {super.key, this.boxed = true});

  @override
  Widget build(BuildContext context) {
    final color = switch (e.tone) {
      Tone.kill => Saloon.blood,
      Tone.vote => const Color(0xFFF08A5D),
      Tone.info => Saloon.brass,
      Tone.quiet => const Color(0xFF8FA8D6),
    };
    final icon = switch (e.tone) {
      Tone.kill => Icons.dangerous,
      Tone.vote => Icons.front_hand,
      Tone.info => Icons.campaign,
      Tone.quiet => Icons.nights_stay,
    };
    final text = Text.rich(
      TextSpan(
        children: [
          for (final p in e.parts)
            if (p is int)
              _chipSpan(p, s)
            else
              TextSpan(
                text: p as String,
                style: p.length < 12 && p[0].toUpperCase() == p[0] && p != '.' ? const TextStyle(fontWeight: FontWeight.w900) : null,
              ),
        ],
      ),
      style: TextStyle(color: color, fontSize: s.font * 0.95, fontWeight: FontWeight.w600, height: 1.35),
    );
    return Container(
      margin: EdgeInsets.symmetric(vertical: s.gap),
      padding: boxed ? EdgeInsets.symmetric(horizontal: s.font * 0.5, vertical: s.font * 0.18) : EdgeInsets.only(left: s.font * 0.2),
      decoration: boxed
          ? BoxDecoration(
              color: color.withValues(alpha: 0.09),
              border: Border(left: BorderSide(color: color, width: 3)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: s.font * 0.22),
            child: Icon(icon, size: s.font * 0.95, color: color),
          ),
          SizedBox(width: s.font * 0.4),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// "3 Carmela: message". The number first and fixed-width, the name in the
/// seat's colour, the message in cream. A line that names my seat or my
/// name gets a brass band; the dead and last words are tinted.
class SaidLine extends StatelessWidget {
  final Said e;
  final ChatScale s;
  const SaidLine(this.e, this.s, {super.key});

  static final _meCall = RegExp(r'(^|\D)2(\D|$)|bruno', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final d = seat(e.n);
    final mine = e.n == me;
    final called = !mine && _meCall.hasMatch(e.body);
    final ghost = e.lastWords;
    final special = d.shown == Role.sindaco && !d.dead;
    final nameColor = ghost ? const Color(0xFF9A928A) : (mine ? AppColors.textPrimary : hueOf(e.n));
    final bodyColor = ghost ? const Color(0xFFA8A098) : AppColors.textPrimary;
    final tint = called
        ? const Color(0x40D9B45A)
        : ghost
        ? const Color(0x22FFFFFF)
        : special
        ? const Color(0x1AD9B45A)
        : mine
        ? const Color(0x14FFFFFF)
        : null;
    final bar = called ? Saloon.brass : (ghost ? const Color(0xFF6E6862) : (special ? Saloon.brassDeep : null));
    return Container(
      margin: EdgeInsets.symmetric(vertical: s.gap * 0.5),
      padding: EdgeInsets.symmetric(horizontal: s.font * 0.3, vertical: s.gap),
      decoration: BoxDecoration(
        color: tint,
        border: bar == null ? null : Border(left: BorderSide(color: bar, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: s.font * 0.06),
            child: SeatChip(e.n, size: s.chip, faded: d.dead),
          ),
          SizedBox(width: s.font * 0.45),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (special)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: s.font * 0.2),
                        child: RoleIcon(Role.sindaco, size: s.font * 1.05),
                      ),
                    ),
                  TextSpan(
                    text: d.name,
                    style: TextStyle(color: nameColor, fontWeight: FontWeight.w800),
                  ),
                  if (ghost)
                    TextSpan(
                      text: ' † ultime parole',
                      style: TextStyle(color: nameColor, fontStyle: FontStyle.italic, fontSize: s.font * 0.8),
                    ),
                  TextSpan(
                    text: ': ',
                    style: TextStyle(color: nameColor, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: e.body,
                    style: TextStyle(fontStyle: ghost ? FontStyle.italic : null),
                  ),
                ],
              ),
              style: TextStyle(color: bodyColor, fontSize: s.font, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

Widget entryWidget(Entry e, ChatScale s, {bool band = false}) => switch (e) {
  PhaseEntry() => PhaseRule(e, s, band: band),
  EventEntry() => EventLine(e, s, boxed: !band),
  Said() => SaidLine(e, s),
};

/// One channel tab: Piazza, Famiglia, Cella, Amanti.
class ChannelTab {
  final String label;
  final IconData icon;
  final Color color;
  final int unread;
  final bool locked;
  final bool active;
  const ChannelTab(this.label, this.icon, this.color, {this.unread = 0, this.locked = false, this.active = false});
}

List<ChannelTab> tabs({required bool family}) => [
  ChannelTab('Piazza', Icons.forum, Saloon.brass, active: !family, unread: family ? 4 : 0),
  ChannelTab('Famiglia', Icons.theater_comedy, Saloon.mafia, unread: family ? 0 : 3, active: family),
  const ChannelTab('Cella', Icons.lock, Color(0xFF8FA8D6), locked: true),
  const ChannelTab('Amanti', Icons.favorite, Color(0xFFEFA0B8), locked: true),
];

class TabBarRow extends StatelessWidget {
  final List<ChannelTab> items;
  final ChatScale s;
  const TabBarRow(this.items, this.s, {super.key});

  /// On the phone a locked channel is only its padlock: the open ones keep
  /// their whole name.
  Widget _slot({required bool iconOnly, required Widget child}) =>
      iconOnly ? SizedBox(width: s.font * 3, child: child) : Expanded(child: child);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final t in items) ...[
        _slot(
          iconOnly: t.locked && s.font < 16,
          child: Container(
            height: s.chip * 1.55,
            padding: EdgeInsets.symmetric(horizontal: s.font * 0.5),
            decoration: BoxDecoration(
              color: t.active ? t.color.withValues(alpha: 0.18) : Saloon.ink.withValues(alpha: 0.6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(s.font * 0.5)),
              border: Border.all(color: t.active ? t.color : Saloon.brassDeep.withValues(alpha: 0.5), width: t.active ? 1.6 : 1),
            ),
            child: Opacity(
              opacity: t.locked ? 0.4 : 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.locked ? Icons.lock_outline : t.icon, size: s.font * 1.05, color: t.color),
                  if (!(t.locked && s.font < 16)) ...[
                    SizedBox(width: s.font * 0.35),
                    Flexible(
                      child: Text(
                        t.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          color: t.active ? AppColors.textPrimary : t.color,
                          fontSize: s.font * 0.78,
                          fontWeight: FontWeight.w900,
                          letterSpacing: s.font * 0.08,
                        ),
                      ),
                    ),
                  ],
                  if (t.unread > 0) ...[
                    SizedBox(width: s.font * 0.35),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: s.font * 0.35, vertical: 1),
                      decoration: BoxDecoration(color: Saloon.enamel, borderRadius: BorderRadius.circular(s.font)),
                      child: Text(
                        '${t.unread}',
                        style: TextStyle(color: Colors.white, fontSize: s.font * 0.72, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: s.font * 0.2),
      ],
    ],
  );
}

/// The log: newest at the bottom, a "new messages" pill when scrolled up.
class ChatLog extends StatelessWidget {
  final List<Entry> entries;
  final ChatScale s;
  final bool band;
  final int? newBelow;
  const ChatLog(this.entries, this.s, {super.key, this.band = false, this.newBelow});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s.font * 0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in entries) entryWidget(e, s, band: band),
                  SizedBox(height: s.gap * 2),
                ],
              ),
            ),
          ),
        ),
      ),
      // Older lines fade under the tabs.
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: s.font * 2.5,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xF50C0907), const Color(0x000C0907)],
              ),
            ),
          ),
        ),
      ),
      if (newBelow != null)
        Positioned(
          right: s.font,
          bottom: s.font * 0.6,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: s.font * 0.7, vertical: s.font * 0.3),
            decoration: BoxDecoration(
              color: Saloon.brass,
              borderRadius: BorderRadius.circular(s.font * 2),
              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward, size: s.font, color: Saloon.ink),
                SizedBox(width: s.font * 0.3),
                Text(
                  '$newBelow nuovi',
                  style: TextStyle(color: Saloon.ink, fontSize: s.font * 0.8, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// The input, always at the bottom: the seat picked on the table becomes a
/// "4 Dario" tag at the start, and quick lines sit just above.
class ChatInput extends StatelessWidget {
  final ChatScale s;
  final String channel;
  final Color color;
  final int? tagged;
  final String typed;
  final List<String> quick;
  const ChatInput(this.s, {super.key, required this.channel, required this.color, this.tagged, this.typed = '', this.quick = const []});

  @override
  Widget build(BuildContext context) {
    final h = s.chip * 1.8;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (quick.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: s.font * 0.45),
            child: Wrap(
              spacing: s.font * 0.4,
              runSpacing: s.font * 0.3,
              children: [
                for (final q in quick)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: s.font * 0.6, vertical: s.font * 0.22),
                    decoration: BoxDecoration(
                      color: Saloon.ink,
                      borderRadius: BorderRadius.circular(s.font),
                      border: Border.all(color: Saloon.brassDeep),
                    ),
                    child: Text(
                      q,
                      style: TextStyle(color: Saloon.brass, fontSize: s.font * 0.78, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: h,
                padding: EdgeInsets.symmetric(horizontal: s.font * 0.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF17110C),
                  borderRadius: BorderRadius.circular(h / 2),
                  border: Border.all(color: color.withValues(alpha: 0.8), width: 1.4),
                ),
                child: Row(
                  children: [
                    if (tagged != null) ...[
                      Container(
                        padding: EdgeInsets.fromLTRB(2, 2, s.font * 0.4, 2),
                        decoration: BoxDecoration(color: Saloon.brass.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(h)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SeatChip(tagged!, size: s.chip * 0.85),
                            SizedBox(width: s.font * 0.3),
                            Text(
                              seat(tagged!).name,
                              style: TextStyle(color: hueOf(tagged!), fontSize: s.font * 0.9, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: s.font * 0.4),
                    ],
                    Expanded(
                      child: Text(
                        typed.isEmpty ? 'Scrivi in $channel...' : typed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: typed.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                          fontSize: s.font,
                          fontStyle: typed.isEmpty ? FontStyle.italic : null,
                        ),
                      ),
                    ),
                    if (typed.isNotEmpty) Container(width: 1.5, height: s.font * 1.2, color: Saloon.brass),
                  ],
                ),
              ),
            ),
            SizedBox(width: s.font * 0.45),
            TargaIconButton(icon: Icons.send, onPressed: () {}, size: h),
          ],
        ),
      ],
    );
  }
}

/// The roles dealt this game, as icons only: the revealed dead are grey and
/// crossed, with a small count. One glance, one row.
class RolesStrip extends StatelessWidget {
  final double icon;
  final bool vertical;
  final bool labels;
  const RolesStrip({super.key, required this.icon, this.vertical = false, this.labels = false});

  static const _grey = ColorFilter.matrix(<double>[
    0.3, 0.3, 0.3, 0, 0, //
    0.3, 0.3, 0.3, 0, 0, //
    0.3, 0.3, 0.3, 0, 0, //
    0, 0, 0, 0.7, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final tiles = <Widget>[];
    for (final MapEntry(key: role, value: count) in deck.entries) {
      final out = gone[role] ?? 0;
      final allOut = out >= count;
      final badge = out > 0 ? '$out/$count' : (count > 1 ? '×$count' : null);
      final ico = allOut
          ? ColorFiltered(
              colorFilter: _grey,
              child: RoleIcon(role, size: icon),
            )
          : RoleIcon(role, size: icon);
      final tile = Stack(
        clipBehavior: Clip.none,
        children: [
          ico,
          if (allOut) Positioned.fill(child: CustomPaint(painter: _Cross())),
          if (badge != null)
            Positioned(
              right: -icon * 0.22,
              bottom: -icon * 0.1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: icon * 0.08),
                decoration: BoxDecoration(
                  color: out > 0 ? const Color(0xFF5A1A20) : Saloon.ink,
                  borderRadius: BorderRadius.circular(icon * 0.2),
                  border: Border.all(color: Saloon.brassDeep, width: 0.8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: icon * 0.3, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      );
      if (labels) {
        tiles.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              SizedBox(width: icon * 0.4),
              Text(
                t.role(role).label,
                style: TextStyle(
                  color: allOut ? AppColors.textSecondary : (role.team == Team.mafia ? Saloon.mafia : AppColors.textPrimary),
                  fontSize: icon * 0.38,
                  fontWeight: FontWeight.w700,
                  decoration: allOut ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        );
      } else {
        tiles.add(tile);
      }
    }
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in tiles)
            Padding(
              padding: EdgeInsets.symmetric(vertical: icon * 0.1),
              child: w,
            ),
        ],
      );
    }
    return Wrap(spacing: icon * 0.32, runSpacing: icon * 0.2, children: tiles);
  }
}

class _Cross extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Saloon.blood.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.2), Offset(size.width * 0.8, size.height * 0.8), p);
    canvas.drawLine(Offset(size.width * 0.8, size.height * 0.2), Offset(size.width * 0.2, size.height * 0.8), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The table: every seat with number, name, votes and the pizzino of whom
/// they accuse. The seat tagged in the input wears the brass halo.
class SeatGrid extends StatelessWidget {
  final double width;
  final int columns;
  final double hGap;
  final double vGap;
  final int? tagged;
  const SeatGrid({super.key, required this.width, required this.columns, required this.hGap, required this.vGap, this.tagged});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < seats.length; i += columns) {
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in seats.sublist(i, (i + columns).clamp(0, seats.length)))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hGap / 2),
                child: SeatCard(
                  name: d.name,
                  number: d.n,
                  width: width,
                  fallen: d.dead,
                  me: d.n == me,
                  votes: d.votes,
                  accused: d.votes >= 4,
                  accusedLabel: 'In testa',
                  selected: d.n == tagged,
                  selectable: !d.dead && d.n != me,
                  pizzino: d.votesFor == null ? null : '→ ${d.votesFor} ${seat(d.votesFor!).name}',
                  role: d.shown ?? (d.family ? Role.mafioso : null),
                  noteColor: d.family && d.shown == null ? Saloon.mafia : Saloon.brass,
                  onTap: () {},
                ),
              ),
          ],
        ),
      );
      rows.add(SizedBox(height: vGap));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows..removeLast());
  }
}

/// The felt under the seats.
BoxDecoration felt() => const BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -0.1),
    radius: 1.0,
    colors: [Color(0xFF24563C), Saloon.feltDeep, Color(0xFF071209)],
    stops: [0, 0.7, 1],
  ),
);

/// The bar on top: phase, ribbon, clock.
class DemoHud extends StatelessWidget {
  final double k;
  const DemoHud({super.key, required this.k});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TargaIconButton(icon: Icons.menu, onPressed: () {}, size: 44 * k),
      const Spacer(),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('GIORNO 2', style: Saloon.plate(26 * k, color: Saloon.brass)),
          SizedBox(height: 4 * k),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 2 * k),
            decoration: BoxDecoration(color: Saloon.enamel, borderRadius: BorderRadius.circular(4 * k)),
            child: Text(
              'SI VOTA · 6 VOTI PER GIUSTIZIARE',
              style: TextStyle(color: const Color(0xFFFFEBD6), fontSize: 11 * k, fontWeight: FontWeight.w900, letterSpacing: 1.6 * k),
            ),
          ),
        ],
      ),
      const Spacer(),
      Text('0:42', style: Saloon.plate(30 * k, color: Saloon.brass)),
    ],
  );
}

/// The vote tally, what the competitor shows as hands on seats.
class VoteTally extends StatelessWidget {
  final double k;
  const VoteTally({super.key, required this.k});

  @override
  Widget build(BuildContext context) {
    Widget bar(int n, int votes) => Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * k),
      child: Row(
        children: [
          SeatChip(n, size: 22 * k),
          SizedBox(width: 6 * k),
          SizedBox(
            width: 70 * k,
            child: Text(
              seat(n).name,
              style: TextStyle(color: hueOf(n), fontSize: 15 * k, fontWeight: FontWeight.w800),
            ),
          ),
          for (var i = 0; i < 6; i++)
            Container(
              width: 12 * k,
              height: 18 * k,
              margin: EdgeInsets.only(right: 3 * k),
              decoration: BoxDecoration(
                color: i < votes ? Saloon.blood : Colors.transparent,
                borderRadius: BorderRadius.circular(2 * k),
                border: Border.all(color: Saloon.blood.withValues(alpha: 0.7)),
              ),
            ),
          SizedBox(width: 4 * k),
          Text(
            '$votes/6',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14 * k, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'IN TESTA',
          style: TextStyle(color: Saloon.blood, fontSize: 12 * k, fontWeight: FontWeight.w900, letterSpacing: 2 * k),
        ),
        SizedBox(height: 4 * k),
        bar(4, 4),
        bar(10, 2),
      ],
    );
  }
}

/// The action strip, cut down: status on the left, Targa buttons on the right.
class DemoStrip extends StatelessWidget {
  final double k;
  final bool desk;
  final String status;
  const DemoStrip({super.key, required this.k, this.desk = false, this.status = 'Accusi 4 Dario. Tocca un altro posto per cambiare.'});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16 * k, vertical: 10 * k),
    decoration: Saloon.scrim(radius: 14 * k),
    child: Row(
      children: [
        Icon(Icons.touch_app_outlined, color: Saloon.brass, size: 22 * k),
        SizedBox(width: 8 * k),
        Expanded(
          child: Text(
            status,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16 * k, height: 1.25),
          ),
        ),
        SizedBox(width: 10 * k),
        TargaButton(label: 'Ritira', kind: TargaKind.secondary, onPressed: () {}, compact: true, desk: desk),
        SizedBox(width: 8 * k),
        TargaButton(label: 'Conferma', onPressed: () {}, compact: true, desk: desk),
      ],
    ),
  );
}
