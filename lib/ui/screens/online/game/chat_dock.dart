import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../online/online_services.dart';
import '../../../press.dart';
import '../../../theme/app_theme.dart';
import '../online_widgets.dart';
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

  const ChatDock({
    super.key,
    required this.view,
    required this.messages,
    required this.myId,
    required this.labels,
    required this.onSend,
    required this.source,
    required this.read,
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
          return ChatSheet(view: now.view, messages: now.messages, myId: myId, labels: labels, onSend: onSend);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    for (final message in last) _Line(message, mine: message.profileId == myId, accent: view.accent, maxLines: 1),
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

class _Line extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final Color accent;
  final int? maxLines;

  const _Line(this.message, {required this.mine, required this.accent, this.maxLines});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '${message.name}  ',
              style: TextStyle(color: mine ? accent : Saloon.brass, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: message.body),
          ]),
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.3),
        ),
      );
}

/// La chat aperta: tutti i messaggi e, se si può, il campo per scrivere.
class ChatSheet extends StatefulWidget {
  final ChatChannelView view;
  final List<ChatMessage> messages;
  final String myId;
  final ChatLabels labels;
  final Future<void> Function(String body) onSend;

  const ChatSheet({super.key, required this.view, required this.messages, required this.myId, required this.labels, required this.onSend});

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  /// Perché l'ultimo messaggio non è partito: si legge qui, nel foglio (un
  /// avviso in fondo allo schermo resterebbe nascosto dietro).
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
  Widget build(BuildContext context) {
    final view = widget.view;
    final messages = widget.messages;
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
                child: messages.isEmpty
                    ? Center(child: Text(widget.labels.empty, style: AppText.body.copyWith(fontStyle: FontStyle.italic)))
                    : ListView.builder(
                        key: const Key('chat.messages'),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          return _Line(message, mine: message.profileId == widget.myId, accent: view.accent);
                        },
                      ),
              ),
              const SizedBox(height: 8),
              if (_failure case final failure? when view.note == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(failure, key: const Key('chat.failure'), textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: const Color(0xFFFF8A80), fontSize: 13)),
                ),
              if (view.note case final note?)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: Saloon.scrim(radius: 10),
                  child: Text(note, key: const Key('chat.note'), textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 14)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1712),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Saloon.brassDeep),
                  ),
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('chat.field'),
                          controller: _text,
                          autofocus: true,
                          maxLength: 300,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          cursorColor: Saloon.brass,
                          decoration: InputDecoration(
                            hintText: widget.labels.hint,
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            counterText: '',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('chat.send'),
                        tooltip: widget.labels.send,
                        onPressed: _sending ? null : _send,
                        icon: Icon(Icons.send, color: view.accent),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
