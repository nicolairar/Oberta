import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../online/online_services.dart';
import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cosmetics/styled_name.dart';
import '../online_widgets.dart';
import 'chat_mentions.dart';
import 'noir_ui.dart';

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
  });

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
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
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: BlockedPlayers.ids,
        builder: (context, _, _) => _strip(context, BlockedPlayers.visible(messages, (m) => m.profileId)),
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
                          child: Text(view.note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontSize: 11, color: AppColors.textSecondary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (last.isEmpty)
                    Text(labels.empty, style: AppText.body.copyWith(fontSize: 13, fontStyle: FontStyle.italic))
                  else
                    for (final message in last) _Line(message, mine: message.profileId == myId, accent: view.accent, seats: seats, maxLines: 1),
                ],
              ),
            ),
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
/// tutta la partita) e il proprio numero e nome, per le chiamate in causa.
class ChatSeats {
  final Map<String, int> numbers;
  final int? myNumber;
  final String? myName;

  const ChatSeats({this.numbers = const {}, this.myNumber, this.myName});

  static const none = ChatSeats();

  int? numberOf(ChatMessage message) => message.seat == null ? null : numbers[message.seat];

  /// «3 anna», o solo il nome se il posto non si sa.
  String tagOf(ChatMessage message) => switch (numberOf(message)) {
        final n? => '$n ${message.name}',
        null => message.name,
      };

  /// Il messaggio chiama in causa questo telefono (mai i propri).
  bool calls(ChatMessage message, {required bool mine}) =>
      mentions(message.body, number: myNumber, name: myName, fromMe: mine);
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

  const _Line(this.message,
      {required this.mine, required this.accent, required this.seats, this.maxLines, this.fontSize = 14.5});

  @override
  Widget build(BuildContext context) {
    final called = seats.calls(message, mine: mine);
    return Container(
      key: called ? ValueKey('chat.mention-${message.id}') : null,
      margin: EdgeInsets.symmetric(vertical: fontSize > 16 ? 3 : 1),
      padding: EdgeInsets.symmetric(horizontal: called ? 6 : 0, vertical: called ? 2 : 1),
      decoration: called
          ? BoxDecoration(
              color: _mentionBand,
              borderRadius: BorderRadius.circular(6),
              border: const Border(left: BorderSide(color: Saloon.brass, width: 3)),
            )
          : null,
      child: Text.rich(
        TextSpan(children: [
          StyledName.span(
            message.name,
            text: '${seats.tagOf(message)}: ',
            style: TextStyle(color: mine ? accent : Saloon.brass, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: message.body),
        ]),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.textPrimary, fontSize: fontSize, height: 1.3),
      ),
    );
  }
}

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
  });

  @override
  State<ChatLog> createState() => _ChatLogState();
}

class _ChatLogState extends State<ChatLog> {
  final _text = TextEditingController();
  bool _sending = false;

  /// Perché l'ultimo messaggio non è partito: si legge qui, accanto al campo.
  String? _failure;

  @override
  void dispose() {
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
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: BlockedPlayers.ids,
        builder: (context, _, _) => _log(context, BlockedPlayers.visible(widget.messages, (m) => m.profileId)),
      );

  Widget _log(BuildContext context, List<ChatMessage> messages) {
    final view = widget.view;
    // Sul desktop: testi da 1080p, una riga sola (INVIO manda), il tasto
    // destro su un messaggio per segnalarlo.
    final desk = NoirDesk.of(context);
    final small = desk ? 16.0 : 13.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header)
          Padding(
            padding: EdgeInsets.only(bottom: desk ? 14 : 4),
            child: Row(
              children: [
                Icon(view.note == null ? Icons.chat_bubble : Icons.lock, size: desk ? 20 : 13, color: view.accent),
                SizedBox(width: desk ? 10 : 6),
                Text(view.title.toUpperCase(),
                    style: AppText.overline.copyWith(color: view.accent, fontSize: desk ? 16 : 12, letterSpacing: desk ? 3.2 : null)),
                const Spacer(),
                ?widget.trailing,
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text(widget.labels.empty, style: AppText.body.copyWith(fontSize: desk ? 18 : 13, fontStyle: FontStyle.italic)))
              : ListView.builder(
                  key: const Key('chat.messages'),
                  reverse: true,
                  padding: EdgeInsets.zero,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final mine = message.profileId == widget.myId;
                    final line = _Line(message,
                        mine: mine, accent: view.accent, seats: widget.seats, fontSize: desk ? 19 : 14.5);
                    final hold = widget.onHold;
                    if (mine || hold == null) return line;
                    return GestureDetector(
                      key: ValueKey('chat.hold-${message.id}'),
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => hold(message),
                      onSecondaryTap: () => hold(message),
                      child: line,
                    );
                  },
                ),
        ),
        SizedBox(height: desk ? 14 : 6),
        if (_failure case final failure? when view.note == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(failure, key: const Key('chat.failure'), textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: const Color(0xFFFF8A80), fontSize: small)),
          ),
        if (view.note case final note?)
          Container(
            padding: EdgeInsets.symmetric(horizontal: desk ? 20 : 12, vertical: desk ? 16 : 8),
            decoration: Saloon.scrim(radius: 10),
            child: Text(note, key: const Key('chat.note'), textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: desk ? 17 : 13.5, height: 1.35)),
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
                    focusNode: widget.focusNode,
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
                child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Saloon.brassDeep, borderRadius: BorderRadius.circular(2))),
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
