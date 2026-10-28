import 'package:flutter/material.dart';

import '../../sound/memes.dart';
import '../../sound/sound_stage.dart';
import '../../l10n/app_strings.dart';
import '../../rules/game_setup.dart';
import '../../narration/narrator_script.dart';
import '../../l10n/table_strings.dart';
import '../desktop/desktop_canvas.dart';
import '../widgets/content_width.dart';
import '../widgets/noir_modal.dart';
import '../widgets/spoken_lines.dart';
import 'local/local_table.dart';
import 'online/game/action_strip.dart';
import 'online/game/noir_role_card.dart';
import 'online/game/noir_ui.dart';
import 'online/game/saloon_table.dart' show SaloonBackdrop;
import 'game_screen.dart';

/// Finché c'è un solo telefono, la carta si guarda a turno passandoselo.
/// Con la rete vera ognuno vedrà solo il pezzo "carta" sul proprio schermo.
class RoleRevealScreen extends StatefulWidget {
  final GameSetup setup;

  const RoleRevealScreen({super.key, required this.setup});

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> {
  @override
  void initState() {
    super.initState();
    // Mentre ognuno guarda la sua carta, in modalità meme parte la canzoncina.
    SoundStage.instance.meme(Meme.englishSpanish);
  }

  /// Solo per le parole della tenda: la città non conta.
  late final NarratorScript _script = NarratorScript(pack: AppStrings.of(context).pack);

  int _index = 0;
  bool _holdingPhone = false;
  bool _seen = false;

  void _next() {
    final players = widget.setup.players;
    if (_index + 1 < players.length) {
      setState(() {
        _index++;
        _holdingPhone = false;
        _seen = false;
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GameScreen(setup: widget.setup)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    final players = setup.players;
    final player = players[_index];
    final t = AppStrings.of(context);
    final ts = TableStrings(t.language);
    final curtain = _script.curtain(player.name, card: true);
    final desk = DesktopCanvas.of(context);
    final tag = '${_index + 1} ${player.name}';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Saloon.ink,
        body: SaloonBackdrop(
          night: true,
          child: SafeArea(
            child: Column(
              children: [
                StageHeader(title: t.cardOf(_index + 1, players.length)),
                Expanded(
                  child: ContentWidth(
                    maxWidth: 780,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
                        child: _holdingPhone
                            ? Column(
                                key: ValueKey('card-$_index'),
                                children: [
                                  Text(tag.toUpperCase(), style: Saloon.plate(desk ? 30 : 22)),
                                  Expanded(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: NoirRoleCard(
                                          role: setup.roleOf(player),
                                          teammates: setup.teammatesOf(player),
                                          onRevealed: () => setState(() => _seen = true),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: ActionStrip.heightFor(desk: desk),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 560),
                                        child: ActionStrip(
                                          status: _seen ? _script.putPhoneDown().text : ts.holdTheCard,
                                          tone: _seen ? StripTone.done : StripTone.act,
                                          actions: [
                                            NoirAction(
                                              key: const Key('local.gotIt'),
                                              label: t.gotIt,
                                              style: NoirButtonStyle.primary,
                                              feel: Press.confirm,
                                              onPressed: _seen ? _next : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : SpokenLines(
                                key: ValueKey('handoff-$_index'),
                                lines: curtain,
                                reader: setup.narrator?.name,
                                child: LocalCurtain(
                                  player: player,
                                  number: _index + 1,
                                  hint: curtain.last.text,
                                  onReady: () => setState(() => _holdingPhone = true),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
