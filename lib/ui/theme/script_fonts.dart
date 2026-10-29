/// The fonts that draw what Georgia and Courier cannot: Chinese, Japanese,
/// Korean, Arabic, Hebrew, Devanagari, Thai... A player's name or a chat line
/// can be in any script, whatever the interface language.
///
/// Nothing is bundled: every list names the system fonts of each platform
/// first (Apple, Windows, Android/Linux Noto), and the engine still falls back
/// to any installed font for a glyph none of them has. Bundling the Noto
/// families would add 10-20 MB per CJK script; if a platform ever lacks them
/// (the web, a bare Linux), add a Noto Sans subset under assets/fonts/ and
/// put its family name at the head of [scriptFallback] (docs/tecnico.md).
library;

/// Per script, the platform fonts in order of preference.
const scriptFallback = <String>[
  // Chinese, Japanese, Korean.
  'PingFang SC', 'Hiragino Sans', 'Apple SD Gothic Neo',
  'Microsoft YaHei', 'Yu Gothic UI', 'Malgun Gothic',
  'Noto Sans CJK SC', 'Noto Sans CJK JP', 'Noto Sans CJK KR',
  // Arabic, Persian, Urdu.
  'Geeza Pro', 'Segoe UI', 'Noto Naskh Arabic', 'Noto Sans Arabic',
  // Hebrew.
  'Arial Hebrew', 'Noto Sans Hebrew',
  // Devanagari and the other Indic scripts.
  'Kohinoor Devanagari', 'Nirmala UI', 'Noto Sans Devanagari',
  // Thai.
  'Thonburi', 'Leelawadee UI', 'Noto Sans Thai',
  // Everything else, emoji included.
  'Noto Sans', 'Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji',
];

/// After Georgia: a serif, then every script.
const serifFallback = <String>['serif', 'Noto Serif', ...scriptFallback];

/// After Courier: a monospace, then every script.
const monoFallback = <String>['monospace', 'Noto Sans Mono', ...scriptFallback];
