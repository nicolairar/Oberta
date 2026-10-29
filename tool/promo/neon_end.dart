// The end-card neon of the promo shorts, wired like the game's home sign
// (home_screen.dart `_wire`): the letters strike one after another, then the
// faulty B buzzes and dies, and while it is dark the ghost M behind it
// stutters on, so for a moment the sign reads OMERTÀ, before the B strikes
// back and it is OBERTÀ again. In the last 0.3 s everything shorts out to
// black, for the loop.
import 'package:oberta/ui/widgets/home_neon_sign.dart';

/// Seconds into the end card at which the B starts to buzz.
const neonBuzzAt = 0.8;

/// The B is dark (the ghost M flickering) from here…
const neonGhostFrom = neonBuzzAt + 12 / 16;

/// …to here, when the B strikes back.
const neonGhostTo = neonGhostFrom + 0.9;

/// The game's ambient clock, shifted so its first B fault (at 3.0 s, dark
/// for 0.9 s) lands [neonBuzzAt] seconds into the card.
const _ambientFrom = 3.0 - neonBuzzAt;

/// Wires [state] for end-card time [u] of a card [length] seconds long.
void wireEndNeon(HomeNeonState state, double u, double length) {
  final seconds = _ambientFrom + u;
  final intro = 0.85 + u * 1.6;
  final off = u - (length - 0.3);
  final jolt = off <= 0 ? 1.0 : (off > 0.2 ? 0.0 : HomeNeonSign.shortAt(off / 0.2));
  final ghost = off > 0.2 ? 0.0 : HomeNeonSign.ghostAt(seconds, intro, jolt: jolt);
  state.set([for (final p in HomeNeonSign.powerAt(seconds, intro)) p * jolt], ghost: ghost);
}
