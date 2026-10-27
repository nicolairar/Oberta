# Steam store page kit

Everything to fill in the Steamworks store page and library assets for Obertà.
Images are rendered from the game's own painters and layouts, not drawn by hand:
run `steam/store/make.sh` (macOS) after any UI change to redo them.

| Path | What |
|---|---|
| `text/en.md` | Name, short description, About this game (BBCode), features, tags, categories, content survey, system requirements, languages |
| `text/it.md` | The same in Italian (name, short description, About, features, languages) |
| `achievements.csv` / `.md` | The 31 in-game achievements for Steamworks (API name = in-game id) |
| `art/header_capsule_920x430.png` | Header capsule |
| `art/small_capsule_462x174.png` | Small capsule |
| `art/main_capsule_1232x706.jpg` | Main capsule |
| `art/vertical_capsule_748x896.png` | Vertical capsule |
| `art/library_capsule_600x900.png` | Library capsule |
| `art/library_hero_3840x1240.jpg` | Library hero, no text (the neon sign is just above the frame) |
| `art/library_logo_1280x720.png` | Library logo, transparent PNG |
| `art/page_background_1438x810.jpg` | Store page background |
| `art/community_icon_184x184.png` | Community icon |
| `art/client_icon.ico`, `client_icon_32x32.png`, `client_icon_256x256.png` | Client icon |
| `screenshots/en/*.jpg`, `screenshots/it/*.jpg` | Ten 1920×1080 desktop screenshots per language |

Sources: `tool/render/steam_art_render_test.dart`, `tool/render/steam_screenshots_render_test.dart`,
`tool/render/steam_achievements_render_test.dart`.

Before publishing:
- The home screenshot (`01_home`) shows the Ranked poster as "COMING SOON", because ranked is
  still locked in this build (`RANKED_DEBUG`). The texts sell ranked as a feature: when ranked opens,
  re-run `make.sh` so the poster and the copy agree.
- Achievement icons (64×64, achieved and unachieved) are not in the kit yet.
