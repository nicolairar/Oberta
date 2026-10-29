import 'dart:ui' show TextDirection;

import 'package:intl/intl.dart' show Bidi;

/// Text the players write can be in any script, and a line mixes it with
/// ours ("3 Vito: ..."). An Arabic or Hebrew message inside an Italian line
/// keeps its own order when it is isolated: the Unicode first-strong isolate
/// (FSI ... PDI) lets the bidi algorithm pick the message's direction from
/// its first strong letter, without dragging the name or the colon along.
/// Text with no right-to-left letter is left as it is.
String bidiIsolate(String text) => Bidi.hasAnyRtl(text) ? '\u2068$text\u2069' : text;

/// The direction a free text reads in, by its letters.
TextDirection directionOf(String text) => Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
