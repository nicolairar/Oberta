# Skin audit: Cappello, Volto and the barber

Every piece of the Cappello department (hats, hairdos, head effects) and of the Volto department (beards and face marks, glasses, tattoos, face extras, eye shines, hair dyes), plus every barber option, rendered on three players and checked by eye.

- **Players:** Vito (a man with light skin and a short crop), Nadia (a woman with dark skin and a huge afro) and Rosalinda (a woman with olive skin and long hair).
- **Views:** each piece on each player is drawn three ways.
  - The shop hero on a 393×852 phone: the 432 px square, the view toggle and the price tag over it.
  - The round dial thumbnail: 80 px, at 2x.
  - The real `SeatCard` of the table: 74 px with its seat number, at dpr 3.
- **Counts:**
  - 162 shop pieces: 58 hats, 13 hairdos, 10 head effects, 21 face marks and beards, 21 glasses, 12 tattoos, 10 face extras, 9 eye shines and 8 dyes.
  - 121 barber options: 24 hair styles, 12 eye shapes, 4 eye sizes, 12 eye colours, 7 eye shadows, 12 brows, 12 noses, 12 mouths, 7 lip colours, 8 face shapes, 8 details and 3 ages.
  - 288 combinations of hair style and colour.
  - About 2,800 renders in all.

The audit was done in two passes:

1. **Render sheets.** `flutter test tool/audit/skins_cappello_volto_test.dart` writes the sheets to `build/audit/cappello_volto/<group>_<n>_{hero,thumb,seat,coin}.png` (20 pieces per sheet) and the colour grids to `hair_colours_{1,2}.png`. The `coin` sheets show the round portrait of the mirror and the home, for the head pieces. To check a few pieces at a larger size, run it with `ONLY=hat.sombrero,face.walrus ZOOM=393`.
2. **A walk through the real app, as a player.** The test backend is used, and the player signs in with the face of one of the three players. The walk goes in this order:
   - It starts in the street and walks into the Bottega.
   - It opens the Cappello and Volto medallions and turns the dial through every piece, first as the bust and then back as the seat card.
   - It buys and wears five pieces: `hat.borsalino`, `face.walrus`, `glasses.aviator`, `tattoo.koi` and `eyeShine.star`.
   - It walks to the barber, switches on "Mostra tutto" and taps every option of every tab.
   - It ends by sitting at a table of eight.

   Each step takes a screenshot at the phone's own size.
   - On the iOS simulator (iPhone 16 Pro): `flutter test integration_test/skins_walk_test.dart -d <simulator> --dart-define=WALK_LOOK=nadia --dart-define=WALK_OUT=<absolute folder>`.
   - Headless, at 393×852 and dpr 3 with the notch and the home bar, for iterating: `WALK_LOOK=nadia flutter test tool/audit/skins_walk_headless_test.dart`. It writes to `build/audit/walk/<who>/`.
   - `python3 tool/audit/walk_sheets.py build/audit/walk/<who>` makes contact sheets of the steps.

   - `WALK_SHOP=false` (a `--dart-define` on the simulator) skips the shop and goes straight to the barber and the table, already wearing the five pieces.

   Each full run takes about 480 screenshots. Three runs were made headless, one for each player (Vito, Nadia and Rosalinda). Two were made on the iOS 18.6 simulator as Nadia: the shop pass took 337 screenshots, and the barber and table pass took 149.

## Findings from the walk through the app

| Item(s) | Problem | Severity | Fix |
|---|---|---|---|
| Barber: eye, eye-size, brow, make-up, nose and mouth options | The close-up thumbnails showed the player as he is dressed. His glasses, his shop eye shine (gold stars), his walrus moustache and his cigarette covered the very feature being chosen, so all twelve eye shapes or all twelve mouths looked the same. | High | Close-up options now show only the barber's own face: no glasses, eye shine, face paint, beard or mouth prop (`_close` in `barber_mirror_screen.dart`, phone and desktop). |
| Barber: nose and mouth on the darkest skins (espresso, ebony) | Once the skin was set to espresso, the twelve noses and the mouths were dark ink on dark skin, and every option looked the same in the close-ups and at the table. | High | On the darkest skins, the lines of the nose and the mouth get a thin rim of lamp-lit skin (`_features` in `noir_painter.dart`). |
| Neck tattoos on the phone hero (9 pieces) | The tattoo sat right under the price tag. Playing cards, skull and family crest were half hidden behind the tag of the piece being bought. | High | The hero steps back for tattoos, as it does for suits (`_heroFrame`), so the neck shows above the tag. |
| Afro under hats, in the shop hero | Even after the first fix, at hero size the clipped afro still read as a bowl around the face. | High | Redrawn as two round tufts by the ears. |
| Round portrait (mirror, home) with an afro, a beehive or a tall hat | The top of the hair or hat was cut by the round and its gold ring. | Medium | In the round portrait, a player whose top would reach the ring steps down a little (`LookPainter.top` and the round painter in `player_avatar.dart`). Square portraits keep their size. |
| Buying a piece | The "È tuo" notice covers the department medallions for a few seconds. | Low | Not changed: it belongs to the shop's shared UI, not to a piece. |
| Barber: the head shape options under an afro | All the shapes look alike, because the afro hides the outline of the head. | Low | Not changed: the hair is part of how a shape reads. "Mostra tutto" with a short cut shows them clearly. |
| Eye shines behind dark glasses | The stars and hearts are drawn over the lenses. | — | By design (`glasses.dark`): it reads as "star glasses" and is clear at the table. |

The walk also confirmed, in place, the fixes from the render sheets: Nadia at the table wears the borsalino, the aviators, the star shine, the walrus (with its sheen on dark skin) and the koi tattoo, and every one of them reads on the 74 px seat card.

## Findings from the render sheets

| Item(s) | Problem | Severity | Fix |
|---|---|---|---|
| All 147 head and face pieces (thumbnails) | The fixed zoom of each slot cut pieces off at the dial thumbnail. The crowns of tall hats (top hat, chef's toque, Moretti hats), the brims of wide hats (sombrero, wide brim, tricorn), opera horns and magician ears were cropped. So were the bottoms of beards (viking, horseshoe), the giant glasses, orbiting head effects (only one star or coin showed), hairdos that hang to one side (rainbow ponytail) and every neck tattoo (only a sliver showed). | High | The zoom of each piece is now measured on its pixels on the three players and stored in `lib/ui/screens/shop/shop_focus.dart`, which `_focusOf` uses first. The tool `tool/audit/thumb_focus_gen_test.dart` regenerates it. The zoom stays centred on the face unless the piece hangs to one side, and it keeps the eyes in view under hats. |
| Afro under every brimmed hat and cap (about 40 hats) | Under the hat, the lower half of the afro's circle wrapped the jaw like a dark bowl. | High | Under a hat, the afro is clipped to a puff that swells at the sides and ends by the cheeks (`_Noir.parts`). |
| Beards and moustaches on dark skin (17 pieces) | A black beard on ebony skin was invisible at the table and barely visible in the shop (mustache, pencil, walrus, handlebar, imperial, goatee, chevron, vandyke and the rest). | High | When both the skin and the hair are dark, the beard takes a cool sheen (`LookPainter._beardColor`). This applies to the noir beards and the shop beards. |
| `faceExtras.skullPaint` | It drew only dark eye sockets and teal dots, with no bone-white paint. It did not read as a skull, and it vanished on dark skin. | High | Redrawn: the face is painted bone white, like the mime face. The sockets are black with a glint, plus a nose hole, a stitched grin and sugar-skull dots. |
| Neck tattoos (9 pieces), `tattoo.cheekStar` | The navy ink vanished on dark skin. At the table the tattoos were a few pixels wide. | High | On dark skin, the ink gets a rim of lighter, healed skin (a dilated layer). At table size the neck tattoos are drawn at 1.75x instead of 1.4x, and the cheek star is larger. |
| `face.stubble` | A flat band, lighter than the face shadow, with a hard edge at the nose. It read as a rendering glitch. | Medium | The band is now multiplied, so the lamp's shadow stays, with a grain of beard dots in the shop. |
| `faceExtras.beautyStar` | A navy star on the cheek, invisible on dark skin. | Medium | The star is now dark with a gold edge, and slightly larger. |
| `hat.ufoHat` | The tractor beam ended in a hard horizontal edge across the forehead, inside a dark outline. | Medium | The beam fades with a gradient and is left out of the ink outline and the ink silhouette. |
| `hat.sombrero` | The brim fell off both sides of the phone screen, and its pompoms were cut by the seat arch. | Medium | The brim is 15% narrower. It is still the widest hat, and now inside the screen and the arch. |
| Long, middle-part, braids and side-part hair | The parting line stuck out above the crown like a small cross, visible in the shop. | Medium | The parting is clipped to the hair. |
| Eye shines on narrow eyes (all 8) | On almond or narrow eyes the shine was tiny, and unreadable at the table. | Medium | The shine has a minimum size tied to the face width. |
| Brows on dark skin (12 shapes) | All the brow shapes looked alike on ebony skin. | Medium | The brows take the beard's sheen on dark skin. Partly fixed: thin brows are still subtle. |
| Salt-and-pepper and grey temples on curly hair and coils | The grey temples were drawn as rectangles, which showed square tabs beside the ears. | Low | They are drawn as ovals. |
| `face.mole` | Invisible at the table on olive and dark skin. | Low | The mole is bigger at the table and has a small glint. |
| Items resting on free hair (halo, crown, cat, UFO, cake, star halo, unicorn) and tall hairdos (beehive, towering pompadour) | The whole player shrinks to make room, most visibly on the afro. | Low | Left as it is. This is the deliberate fit that keeps the piece inside the seat arch. |
| Wide brims (sombrero, wide brim, tricorn) at the table | The seat-number badge overlaps the left tip of the brim. | Low | Left as it is: the table layout is outside this scope. |
| `hat.morettiFedora`, `hat.morettiPanama`, `hat.morettiHomburg` | Heavier brims and a glass-like glint, compared with the house hats. | Low | Left as it is: this is the house brand's look, and it is consistent across the three hats. |
| Afro under brimless caps (coppola, beret, team caps) | The side puff is a little wider than the cap at the cut. | Low | Accepted: it reads as hair pushing out from under the cap. |
| `glasses.eyePatch` on dark skin | The strap is faint. | Low | Left as it is: the patch itself reads. |

Checked with no problem found: the other hats, hairdos and head effects in the hero and seat views; the eye shines, dyes and glasses in all three views; the barber's eyes, eye colours, shadows, noses, mouths, lips, face shapes, details and ages; and the 288 combinations of hair style and colour.

## Automated checks

- `test/ui/shop_thumb_fit_test.dart` checks three rules:
  - Every head and face piece of the catalogue has a measured thumbnail zoom.
  - On each of the three players, at least 96% of the piece's pixels fall inside the round thumbnail.
  - Every piece still changes the 64 px table portrait on every skin. Hats and hairdos must change at least 60 pixels, glasses and head effects 20, and marks 5.
- `test/ui/thumb_measure.dart` holds the pixel measure, which the test and the generator share.
