import 'package:flutter/material.dart';

import '../../../online/online_services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cosmetics/styled_name.dart';
import 'online_widgets.dart';

/// Una chat semplice: i messaggi dal più vecchio (in alto) al più nuovo (in
/// basso, sempre in vista) e, se si può scrivere, il campo per farlo. Chi
/// può scrivere dove lo decide il server: qui si mostra solo [note] quando
/// non si può.
class ChatPanel extends StatefulWidget {
  final String title;
  final List<ChatMessage> messages;
  final String myId;

  /// Null se adesso si può scrivere; altrimenti perché no.
  final String? note;
  final String hint;
  final String empty;
  final String sendLabel;
  final Future<void> Function(String body) onSend;
  final Color accent;

  /// Tenendo premuto il messaggio di un altro (segnalarlo, bloccarlo).
  final void Function(ChatMessage message)? onHold;

  const ChatPanel({
    super.key,
    required this.title,
    required this.messages,
    required this.myId,
    required this.note,
    required this.hint,
    required this.empty,
    required this.sendLabel,
    required this.onSend,
    this.accent = AppColors.gold,
    this.onHold,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(body);
      _text.clear();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: BlockedPlayers.ids,
        builder: (context, _, _) => _panel(context, BlockedPlayers.visible(widget.messages, (m) => m.profileId)),
      );

  Widget _panel(BuildContext context, List<ChatMessage> messages) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppText.overline.copyWith(color: widget.accent)),
            const SizedBox(height: 4),
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text(widget.empty, style: AppText.body.copyWith(fontSize: 13)))
                  : ListView.builder(
                      key: const Key('chat.messages'),
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        final mine = message.profileId == widget.myId;
                        final hold = widget.onHold;
                        return GestureDetector(
                          key: ValueKey('chat.hold-${message.id}'),
                          behavior: HitTestBehavior.opaque,
                          onLongPress: mine || hold == null ? null : () => hold(message),
                          child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                StyledName.span(
                                  message.name,
                                  text: '${message.name}  ',
                                  style: TextStyle(
                                    color: mine ? widget.accent : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: message.body),
                              ],
                            ),
                            style: AppText.body.copyWith(color: AppColors.textPrimary, fontSize: 15, height: 1.3),
                          ),
                        ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 6),
            if (widget.note case final note?)
              Text(note, key: const Key('chat.note'), style: AppText.body.copyWith(fontSize: 13))
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat.field'),
                      controller: _text,
                      maxLength: 300,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        counterText: '',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('chat.send'),
                    tooltip: widget.sendLabel,
                    onPressed: _sending ? null : _send,
                    icon: Icon(Icons.send, color: widget.accent),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
