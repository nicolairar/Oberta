import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../l10n/bidi.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../l10n/game_event_strings.dart';
import '../../../../online/online_services.dart';
import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cosmetics/styled_name.dart';
import '../online_widgets.dart';
import 'chat_mentions.dart';
import 'noir_ui.dart';
import '../../../widgets/noir_modal.dart';
import '../../../theme/script_fonts.dart';

/// Quale chat si vede adesso, e se si può scrivere. Lo decide la fase (e
/// il server): qui si mostra soltanto.
class ChatChannelView {
  final ChatChannel channel;
  final String title;
  final Color accent;

  /// Null se si può scrivere; altrimenti perché no.
  final String? note;

  const ChatChannelView({required this.channel, required this.title, required this.accent, this.note});
}

/// I testi della chat.
class ChatLabels {
  final String hint;
  final String empty;
  final String send;

  const ChatLabels({required this.hint, required this.empty, required this.send});
}

/// La chat sempre a portata: una striscia in fondo con gli ultimi messaggi,
/// che con un tocco si apre in un foglio intero.
class ChatDock extends StatelessWidget {
  final ChatChannelView view;
  final List<ChatMessage> messages;
  final String myId;
  final ChatLabels labels;
  final Future<void> Function(String body) onSend;

  /// Per tenere aggiornato il foglio aperto: chi lo ricostruisce, e come.
  final Listenable source;
  final ({ChatChannelView view, List<ChatMessage> messages}) Function() read;
  final ChatSeats seats;

  /// Tenendo premuto il messaggio di un altro (segnalarlo, bloccarlo).
  final void Function(ChatMessage message)? onHold;

  /// Accanto alla freccia (la voce al tavolo).
  final Widget? trailing;

  const ChatDock({
    super.key,
    required this.view,
    required this.messages,
    required this.myId,
    required this.labels,
    required this.onSend,
    required this.source,
    required this.read,
    this.seats = ChatSeats.none,
    this.onHold,
    this.trailing,
  });

  void _open(BuildContext context) {
    showNoirSheet<void>(
      context,
      builder: (context) => ListenableBuilder(
        listenable: source,
        builder: (context, _) {
          final now = read();
          return ChatSheet(
            view: now.view,
            messages: now.messages,
            myId: myId,
            labels: labels,
            onSend: onSend,
            seats: seats,
            onHold: onHold,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: BlockedPlayers.changes,
    builder: (context, _) => _strip(context, BlockedPlayers.visible(messages, (m) => m.profileId)),
  );

  Widget _strip(BuildContext context, List<ChatMessage> messages) {
    final last = messages.length > 2 ? messages.sublist(messages.length - 2) : messages;
    return GestureDetector(
      key: const Key('chat.dock'),
      behavior: HitTestBehavior.opaque,
      onTap: pressed(() => _open(context), Press.tap),
      child: Container(
        // Sollevata dal bordo: sopra la barra di sistema e lontana dagli
        // angoli, con un margine comodo.
        margin: EdgeInsets.fromLTRB(10, 4, 10, max(MediaQuery.viewPaddingOf(context).bottom, 8) + 8),
        decoration: BoxDecoration(
          color: Saloon.ink.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: view.accent.withValues(alpha: 0.8), width: 1.3),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 14, offset: Offset(0, 4))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(view.note == null ? Icons.chat_bubble : Icons.lock, size: 13, color: view.accent),
                      const SizedBox(width: 6),
                      Text(view.title.toUpperCase(), style: AppText.overline.copyWith(color: view.accent, fontSize: 12)),
                      if (view.note != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            view.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (last.isEmpty)
                    Text(labels.empty, style: AppText.body.copyWith(fontSize: 15, fontStyle: FontStyle.italic))
                  else
                    for (final message in last)
                      _Line(message, mine: message.profileId == myId, accent: view.accent, seats: seats, maxLines: 1),
                ],
              ),
            ),
            if (trailing case final trailing?) Padding(padding: const EdgeInsets.only(left: 6, top: 6), child: trailing),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Saloon.brass),
                  color: const Color(0xFF1A130E),
                ),
                child: const Icon(Icons.keyboard_arrow_up, color: Saloon.brass),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chi è chi nella chat: il numero di posto di ogni seggio (stabile per
/// tutta la partita) e il proprio numero e nome, per le chiamate in causa;
/// chi è morto e chi si è rivelato Sindaco, per tingere le loro righe.
class ChatSeats {
  final Map<String, int> numbers;
  final int? myNumber;
  final String? myName;

  /// I posti dei morti: le loro righe sono grigie.
  final Set<String> fallen;

  /// Il posto del Sindaco rivelato: la sua riga ha un filo d'ottone.
  final String? mayor;

  /// Tutti i posti, in ordine, per citarli toccando il loro numero.
  final List<({int number, String name, bool alive})> roster;

  const ChatSeats({this.numbers = const {}, this.myNumber, this.myName, this.fallen = const {}, this.mayor, this.roster = const []});

  static const none = ChatSeats();

  int? numberOf(ChatMessage message) => message.seat == null ? null : numbers[message.seat];

  /// «3 anna», o solo il nome se il posto non si sa.
  String tagOf(ChatMessage message) => switch (numberOf(message)) {
    final n? => '$n ${message.name}',
    null => message.name,
  };

  /// Il messaggio chiama in causa questo telefono (mai i propri).
  bool calls(ChatMessage message, {required bool mine}) => mentions(message.body, number: myNumber, name: myName, fromMe: mine);
}

/// Un colore di nome per ogni posto: caldi, smorzati, tutti leggibili sul
/// nero. Lo stesso numero ha sempre lo stesso colore.
const _hues = [
  Color(0xFFE8B86B),
  Color(0xFF9FC7E8),
  Color(0xFFE59A8C),
  Color(0xFFA8D69A),
  Color(0xFFD6A6E0),
  Color(0xFFC9B79C),
  Color(0xFF8FD6CC),
  Color(0xFFF0D27A),
  Color(0xFFB0C4F0),
  Color(0xFFEFA0B8),
  Color(0xFFC7C28A),
  Color(0xFF9CB6F0),
];

Color seatHue(int number) => _hues[(number - 1) % _hues.length];

/// Il numero di posto in chat: un gettone d'ottone sempre largo uguale,
/// così i nomi si allineano e il numero è la prima cosa che si legge.
class ChatSeatChip extends StatelessWidget {
  final int number;
  final double size;
  final bool faded;
  final bool me;

  const ChatSeatChip(this.number, {super.key, required this.size, this.faded = false, this.me = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size * 1.2,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.24),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: faded ? const [Color(0xFF6E6862), Color(0xFF3E3935)] : const [Color(0xFFF2D58A), Saloon.brassDeep],
      ),
      border: Border.all(color: me ? Colors.white : const Color(0xFF1A120C), width: me ? 1.4 : 1),
    ),
    child: Text(
      '$number',
      style: TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: serifFallback,
        fontSize: size * 0.66,
        fontWeight: FontWeight.w800,
        height: 1,
        color: const Color(0xFF1A120C),
      ),
    ),
  );
}

/// La fascia delle chiamate in causa: un ottone caldo, appena acceso.
const _mentionBand = Color(0x40D9B45A);

class _Line extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Color accent;
  final int? maxLines;
  final ChatSeats seats;
  final double fontSize;

  const _Line(this.message, {required this.mine, required this.accent, required this.seats, this.maxLines, this.fontSize = 15});

  @override
  Widget build(BuildContext context) {
    if (message.event case final event?) return _EventLine(event, maxLines: maxLines, fontSize: fontSize);
    final called = seats.calls(message, mine: mine);
    final number = seats.numberOf(message);
    final dead = seats.fallen.contains(message.seat);
    final mayor = !dead && message.seat != null && message.seat == seats.mayor;
    final nameColor = dead
        ? const Color(0xFF9A928A)
        : mine
        ? AppColors.textPrimary
        : number != null
        ? seatHue(number)
        : Saloon.brass;
    final tint = called
        ? _mentionBand
        : dead
        ? const Color(0x1FFFFFFF)
        : mayor
        ? const Color(0x1AD9B45A)
        : mine
        ? const Color(0x12FFFFFF)
        : null;
    final bar = called ? Saloon.brass : (mayor ? Saloon.brassDeep : null);
    return Container(
      key: called ? ValueKey('chat.mention-${message.id}') : null,
      margin: EdgeInsets.symmetric(vertical: fontSize > 16 ? 2 : 1),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: fontSize > 16 ? 3 : 2),
      decoration: tint == null && bar == null
          ? null
          : BoxDecoration(
              color: tint,
              border: bar == null ? null : Border(left: BorderSide(color: bar, width: 3)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number != null) ...[
            Padding(
              padding: EdgeInsets.only(top: fontSize * 0.08),
              child: ChatSeatChip(number, size: fontSize * 1.3, faded: dead, me: mine),
            ),
            SizedBox(width: fontSize * 0.45),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  StyledName.span(
                    message.name,
                    text: '${message.name}${dead ? ' †' : ''}: ',
                    style: TextStyle(color: nameColor, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: bidiIsolate(message.body),
                    style: dead ? const TextStyle(fontStyle: FontStyle.italic) : null,
                  ),
                ],
              ),
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: TextStyle(color: dead ? const Color(0xFFB0A89F) : AppColors.textPrimary, fontSize: fontSize, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// A line of the server. Nightfall and daybreak are phase separators: a
/// band across the log in the phase's colour; the rest sit inline in the
/// colour of what happened (blood for deaths and the gallows, brass for
/// news, pink for the family, blue for the night). A private one carries
/// «SOLO TU».
class _EventLine extends StatelessWidget {
  final GameEvent event;
  final int? maxLines;
  final double fontSize;

  const _EventLine(this.event, {this.maxLines, required this.fontSize});

  static const _night = Color(0xFF8FA8D6);

  static (Color, IconData) _look(GameEvent event) => switch (event.kind) {
    'night' => (_night, Icons.nightlight_round),
    'dawn' => (Saloon.brass, Icons.wb_sunny),
    'lynch' => (Saloon.blood, Icons.gavel),
    'end' => (AppColors.gold, Icons.flag),
    'silenced' || 'familyTarget' || 'doused' || 'bounty' => (Saloon.mafia, Icons.theater_comedy),
    'protected' || 'watch' => (_night, Icons.shield_moon),
    'left' => (AppColors.textSecondary, Icons.directions_walk),
    _ => (Saloon.brass, Icons.campaign),
  };

  @override
  Widget build(BuildContext context) {
    final words = GameEventStrings(AppStrings.of(context));
    final text = words.text(event);
    // A line this phone does not know yet (a newer server) stays out.
    if (text.isEmpty) return const SizedBox.shrink();
    final (base, icon) = _look(event);
    final dawnDead = event.kind == 'dawn' && ((event.data['dead'] as List<Object?>?)?.isNotEmpty ?? false);
    final color = dawnDead ? Saloon.blood : base;
    final body = Text.rich(
      TextSpan(
        children: [
          if (event.private)
            TextSpan(
              text: '${words.onlyYou}  ',
              style: TextStyle(color: Saloon.mafia, fontWeight: FontWeight.w900, fontSize: fontSize * 0.75, letterSpacing: 1.4),
            ),
          TextSpan(text: text),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: fontSize * 0.92, fontWeight: FontWeight.w700, height: 1.3),
    );
    final phase = event.kind == 'night' || event.kind == 'dawn';
    if (phase && maxLines == null) {
      return Padding(
        key: ValueKey('chat.event-${event.kind}'),
        padding: EdgeInsets.only(top: fontSize * 0.7, bottom: fontSize * 0.3),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: fontSize * 0.3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.7)),
              bottom: BorderSide(color: color.withValues(alpha: 0.7)),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: fontSize * 1.05, color: color),
              SizedBox(width: fontSize * 0.45),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Container(
      key: ValueKey('chat.event-${event.kind}'),
      margin: EdgeInsets.symmetric(vertical: fontSize > 16 ? 3 : 2),
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.45, vertical: fontSize * 0.2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.12),
            child: Icon(icon, size: fontSize, color: color),
          ),
          SizedBox(width: fontSize * 0.4),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Una linguetta della chat: la piazza, la famiglia. Spenta se adesso non
/// si può aprire; col numero dei messaggi non letti.
class ChatTab {
  final String label;
  final Color accent;
  final IconData icon;
  final bool active;
  final int unread;
  final VoidCallback? onTap;
  final Key? key;

  const ChatTab({
    required this.label,
    required this.accent,
    required this.icon,
    this.active = false,
    this.unread = 0,
    this.onTap,
    this.key,
  });
}

class _Tabs extends StatelessWidget {
  final List<ChatTab> tabs;
  final bool desk;
  final Widget? trailing;

  const _Tabs(this.tabs, {required this.desk, this.trailing});

  @override
  Widget build(BuildContext context) {
    final font = desk ? 15.0 : 12.0;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (final t in tabs) ...[
                Flexible(
                  child: Semantics(
                    button: true,
                    selected: t.active,
                    child: GestureDetector(
                      key: t.key,
                      behavior: HitTestBehavior.opaque,
                      onTap: t.active || t.onTap == null ? null : pressed(t.onTap, Press.tap),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: desk ? 44 : 30,
                        padding: EdgeInsets.symmetric(horizontal: desk ? 14 : 9),
                        decoration: BoxDecoration(
                          color: t.active ? t.accent.withValues(alpha: 0.18) : Saloon.ink.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(desk ? 10 : 8),
                          border: Border.all(
                            color: t.active ? t.accent : Saloon.brassDeep.withValues(alpha: 0.5),
                            width: t.active ? 1.5 : 1,
                          ),
                        ),
                        child: Opacity(
                          opacity: t.active || t.onTap != null ? 1 : 0.45,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon, size: font * 1.25, color: t.accent),
                              SizedBox(width: font * 0.45),
                              Flexible(
                                child: Text(
                                  t.label.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: AppText.overline.copyWith(
                                    color: t.active ? AppColors.textPrimary : t.accent,
                                    fontSize: font,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: font * 0.14,
                                  ),
                                ),
                              ),
                              if (t.unread > 0) ...[
                                SizedBox(width: font * 0.45),
                                Container(
                                  key: const Key('chat.unread'),
                                  constraints: BoxConstraints(minWidth: font * 1.45),
                                  padding: EdgeInsets.symmetric(horizontal: font * 0.35, vertical: 1),
                                  decoration: BoxDecoration(color: Saloon.enamel, borderRadius: BorderRadius.circular(font)),
                                  child: Text(
                                    t.unread > 99 ? '99+' : '${t.unread}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontSize: font * 0.9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: desk ? 8 : 5),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// «↓ 3 nuovi».
String _freshLabel(BuildContext context, int count) => AppStrings.of(context).language.message('chat.fresh', {'n': count});

/// La chat dentro lo schermo, senza foglio: tutti i messaggi (i più nuovi in
/// basso) e, se si può, il campo per scrivere. Di giorno prende quasi tutto
/// lo spazio sotto il tavolo; con la tastiera aperta si stringe.
class ChatLog extends StatefulWidget {
  final ChatChannelView view;
  final List<ChatMessage> messages;
  final String myId;
  final ChatLabels labels;
  final Future<void> Function(String body) onSend;
  final ChatSeats seats;
  final bool autofocus;

  /// Il titolo sopra i messaggi (nel foglio c'è già il suo).
  final bool header;

  /// Accanto al titolo (la scelta tra piazza e famiglia).
  final Widget? trailing;

  /// Tenendo premuto il messaggio di un altro (segnalarlo, bloccarlo).
  final void Function(ChatMessage message)? onHold;

  /// Il fuoco del campo (sul desktop INVIO ci porta da fuori).
  final FocusNode? focusNode;

  /// Al posto del titolo, le linguette delle chat (la piazza, la famiglia)
  /// con i messaggi non letti.
  final List<ChatTab>? tabs;

  const ChatLog({
    super.key,
    required this.view,
    required this.messages,
    required this.myId,
    required this.labels,
    required this.onSend,
    this.seats = ChatSeats.none,
    this.autofocus = false,
    this.header = true,
    this.trailing,
    this.onHold,
    this.focusNode,
    this.tabs,
  });

  @override
  State<ChatLog> createState() => _ChatLogState();
}

class _ChatLogState extends State<ChatLog> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  FocusNode? _ownFocus;
  bool _sending = false;

  /// Perché l'ultimo messaggio non è partito: si legge qui, accanto al campo.
  String? _failure;

  /// I messaggi arrivati mentre si leggeva più su: «↓ 3 nuovi».
  int _fresh = 0;

  /// Il campo ha il fuoco: sopra compaiono i numeri dei posti da citare.
  bool _writing = false;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// La lista è rovesciata: in fondo (i più nuovi) è l'inizio.
  bool get _atBottom => !_scroll.hasClients || _scroll.offset < 40;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatLog old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (old.view.channel != widget.view.channel) {
      _fresh = 0;
    } else if (widget.messages.length > old.messages.length && !_atBottom) {
      _fresh += widget.messages.length - old.messages.length;
    }
  }

  void _onFocus() {
    if (mounted && _writing != _focus.hasFocus) setState(() => _writing = _focus.hasFocus);
  }

  void _onScroll() {
    if (_fresh > 0 && _atBottom) setState(() => _fresh = 0);
  }

  void _toBottom() {
    setState(() => _fresh = 0);
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  /// Il numero di un posto nel campo, dove c'è il cursore: «4 ».
  void _cite(int number) {
    final value = _text.value;
    final at = value.selection.isValid ? value.selection.start : value.text.length;
    final before = value.text.substring(0, at);
    final gap = before.isEmpty || before.endsWith(' ') ? '' : ' ';
    final insert = '$gap$number ';
    final text = before + insert + value.text.substring(at);
    if (text.length > 300) return;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _scroll.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      await widget.onSend(body);
      _text.clear();
    } catch (error) {
      if (mounted) setState(() => _failure = failureText(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: BlockedPlayers.changes,
    builder: (context, _) => _log(context, BlockedPlayers.visible(widget.messages, (m) => m.profileId)),
  );

  Widget _log(BuildContext context, List<ChatMessage> messages) {
    final view = widget.view;
    // Sul desktop: testi da 1080p, una riga sola (INVIO manda), il tasto
    // destro su un messaggio per segnalarlo.
    final desk = NoirDesk.of(context);
    final small = desk ? 16.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tabs case final tabs? when widget.header)
          Padding(
            padding: EdgeInsets.only(bottom: desk ? 12 : 4),
            child: _Tabs(tabs, desk: desk, trailing: widget.trailing),
          )
        else if (widget.header)
          Padding(
            padding: EdgeInsets.only(bottom: desk ? 14 : 4),
            child: Row(
              children: [
                Icon(view.note == null ? Icons.chat_bubble : Icons.lock, size: desk ? 20 : 13, color: view.accent),
                SizedBox(width: desk ? 10 : 6),
                Text(
                  view.title.toUpperCase(),
                  style: AppText.overline.copyWith(color: view.accent, fontSize: desk ? 16 : 12, letterSpacing: desk ? 3.2 : null),
                ),
                const Spacer(),
                ?widget.trailing,
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    widget.labels.empty,
                    style: AppText.body.copyWith(fontSize: desk ? 19 : 15, fontStyle: FontStyle.italic),
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      key: const Key('chat.messages'),
                      controller: _scroll,
                      reverse: true,
                      padding: EdgeInsets.zero,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        final mine = message.profileId == widget.myId;
                        final line = _Line(message, mine: mine, accent: view.accent, seats: widget.seats, fontSize: desk ? 19 : 15);
                        final hold = widget.onHold;
                        if (mine || hold == null || message.event != null) return line;
                        return GestureDetector(
                          key: ValueKey('chat.hold-${message.id}'),
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => hold(message),
                          onSecondaryTap: () => hold(message),
                          child: line,
                        );
                      },
                    ),
                    if (_fresh > 0)
                      Positioned(
                        right: desk ? 12 : 6,
                        bottom: desk ? 10 : 6,
                        child: GestureDetector(
                          key: const Key('chat.fresh'),
                          onTap: pressed(_toBottom, Press.tap),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: desk ? 14 : 10, vertical: desk ? 6 : 4),
                            decoration: BoxDecoration(
                              color: Saloon.brass,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 8)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_downward, size: desk ? 18 : 14, color: Saloon.ink),
                                const SizedBox(width: 4),
                                Text(
                                  _freshLabel(context, _fresh),
                                  style: TextStyle(color: Saloon.ink, fontSize: desk ? 15 : 12, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        SizedBox(height: desk ? 14 : 6),
        if (_failure case final failure? when view.note == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              failure,
              key: const Key('chat.failure'),
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: const Color(0xFFFF8A80), fontSize: small),
            ),
          ),
        if (_writing && view.note == null && widget.seats.roster.isNotEmpty)
          TextFieldTapRegion(
            child: _CiteRow(seats: widget.seats, desk: desk, onCite: _cite),
          ),
        if (view.note case final note?)
          Container(
            padding: EdgeInsets.symmetric(horizontal: desk ? 20 : 12, vertical: desk ? 16 : 8),
            decoration: Saloon.scrim(radius: 10),
            child: Text(
              note,
              key: const Key('chat.note'),
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: desk ? 19 : 15, height: 1.35),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1712),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Saloon.brassDeep),
            ),
            padding: EdgeInsets.only(left: desk ? 20 : 12, right: desk ? 6 : 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat.field'),
                    controller: _text,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    maxLength: 300,
                    minLines: 1,
                    maxLines: desk ? 1 : 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    // Sul desktop il campo resta acceso dopo INVIO: si
                    // continua a scrivere.
                    onEditingComplete: desk ? () {} : null,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: desk ? 19 : 15),
                    cursorColor: Saloon.brass,
                    decoration: InputDecoration(
                      hintText: widget.labels.hint,
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      counterText: '',
                      isDense: true,
                      contentPadding: desk ? const EdgeInsets.symmetric(vertical: 18) : null,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('chat.send'),
                  tooltip: widget.labels.send,
                  visualDensity: desk ? VisualDensity.standard : VisualDensity.compact,
                  iconSize: desk ? 26 : 24,
                  onPressed: _sending ? null : _send,
                  icon: Icon(Icons.send, color: view.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La chat aperta: tutti i messaggi e, se si può, il campo per scrivere.
class ChatSheet extends StatelessWidget {
  final ChatChannelView view;
  final List<ChatMessage> messages;
  final String myId;
  final ChatLabels labels;
  final Future<void> Function(String body) onSend;
  final ChatSeats seats;
  final void Function(ChatMessage message)? onHold;

  const ChatSheet({
    super.key,
    required this.view,
    required this.messages,
    required this.myId,
    required this.labels,
    required this.onSend,
    this.seats = ChatSeats.none,
    this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.62,
        decoration: BoxDecoration(
          color: const Color(0xFF110C09),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: view.accent, width: 1.6)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: Saloon.brassDeep, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(view.note == null ? Icons.chat_bubble : Icons.lock, size: 16, color: view.accent),
                  const SizedBox(width: 8),
                  Text(view.title.toUpperCase(), style: AppText.display(16, color: view.accent)),
                ],
              ),
              const Divider(color: Saloon.brassDeep, height: 18),
              Expanded(
                child: ChatLog(
                  view: view,
                  messages: messages,
                  myId: myId,
                  labels: labels,
                  onSend: onSend,
                  seats: seats,
                  autofocus: true,
                  header: false,
                  onHold: onHold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sopra il campo, mentre si scrive: i numeri dei posti. Un tocco mette il
/// numero nel messaggio, dove c'è il cursore.
class _CiteRow extends StatelessWidget {
  final ChatSeats seats;
  final bool desk;
  final void Function(int number) onCite;

  const _CiteRow({required this.seats, required this.desk, required this.onCite});

  @override
  Widget build(BuildContext context) {
    final chip = desk ? 22.0 : 18.0;
    return SizedBox(
      key: const Key('chat.cite'),
      height: chip + (desk ? 18 : 14),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(bottom: desk ? 8 : 6),
        children: [
          for (final seat in seats.roster)
            if (seat.number != seats.myNumber)
              Padding(
                padding: EdgeInsets.only(right: desk ? 8 : 6),
                child: GestureDetector(
                  key: ValueKey('chat.cite-${seat.number}'),
                  onTap: pressed(() => onCite(seat.number), Press.tap),
                  child: Opacity(
                    opacity: seat.alive ? 1 : 0.5,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(3, 2, desk ? 10 : 7, 2),
                      decoration: BoxDecoration(
                        color: Saloon.ink.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Saloon.brassDeep),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChatSeatChip(seat.number, size: chip, faded: !seat.alive),
                          SizedBox(width: desk ? 6 : 4),
                          Text(
                            seat.name.startsWith('bot.') ? seat.name.substring(4) : seat.name,
                            style: TextStyle(
                              color: seat.alive ? seatHue(seat.number) : AppColors.textSecondary,
                              fontSize: desk ? 15 : 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
