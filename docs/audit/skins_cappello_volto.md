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

The tool that draws the sheets is `flutter test tool/audit/skins_cappello_volto_test.dart`. It writes the sheets to `build/audit/cappello_volto/<group>_<n>_{hero,thumb,seat}.png` (20 pieces per sheet) and the colour grids to `hair_colours_{1,2}.png`. To check a few pieces at a larger size, run it with `ONLY=hat.sombrero,face.walrus ZOOM=393`.

## Findings

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
