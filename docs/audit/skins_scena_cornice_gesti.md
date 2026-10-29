# Skin audit: Scena, Spalle, Mani, Cornice, Gesti, Vetrina

Two passes, each looked at screen by screen, fixed and looked at again.

**As a player** (`integration_test/bottega_walk_test.dart`): the real app
on the test backend, at an iPhone's 393×852 points, 3x, with the notch and
the home bar, in Italian. From the alley into the Bottega; the Vetrina's
three sections; Scena, Spalle, Mani (both hands), Cornice and Gesti, the
dial turned over every piece, in bust and on the seat card; the six
mission-only frames and inks and their «Si sblocca con» line; nine pieces
bought and worn (receipt, bought, worn); back to the alley; then a seat at
a seven-player table (ugo, eva, massimiliana, bartolomeo12, two bots and
massimiliano, each dressed from these shelves), from the card to the first
day, and four gestures thrown at different seats, frame by frame. 280
screens per run, with contact sheets. Run headless
(`flutter test integration_test/bottega_walk_test.dart -d flutter-tester`,
`--dart-define=QUICK=true` for two pieces per shelf) while fixing, and once
in the real macOS app (`-d macos`) at the end. `DESK=true` walks the
desktop shop.

**Piece by piece** (`tool/audit/skins_scena_cornice_gesti_render_test.dart`,
sheets in `build/audit/skins_scena_cornice_gesti/`):

- the phone shop at 393×852, dpr 3, with the iPhone notch and home bar:
  the hero and the price tag for every piece, in bust and in seat-card view
  (`phone_<dept>_bust|card`), the hands in both hands, the frames and inks
  with a short (`ugo`) and a twelve-letter handle (`massimiliano`,
  `phone_frames_long_*`), the frames on a 375×667 phone in English
  (`phone_frames_en_small`), the Vetrina's three sections as they open and
  on the card (`phone_window_*`);
- the dial thumbnail of every piece, at 3x (`thumbs_*`);
- the real `SeatCard` at the table's 74 px, dpr 3, on a man in a fedora and
  a bareheaded woman, as Ugo, Massimiliano, Eva and Massimiliana
  (`table_<slot>`);
- every gesture flying between two seats at six moments of its flight
  (`gestures_flight_*`) and its still art at four moments of its loop
  (`gestures_art_*`);
- the desktop shop at 1600×1000: each department and every mission-only
  frame and ink selected (`desktop_*`).

Checked: 9 scenes, 8 front effects, 9 shoulder pieces, 11 held items (9 in
each hand, 2 two-handed), 14 frames, 13 name inks (with plain), 13
gestures: 77 pieces, and the 28 bundles of the Vetrina.

## Findings

| Item | Problem | Severity | Fix |
|---|---|---|---|
| all name inks, seat card | A long handle (MASSIMILIANO, any twelve letters) was cut to «MASSIMILI…» on the 74 px plate, plain ink included: the shrink stopped at 9 px and then gave up. | High | `_PlateName` shrinks to 8.5 px, then narrows the name horizontally (down to 60%), measured at its real size; it is never cut. Test: `seat_cosmetics_fit_test.dart`. |
| locked frames and inks (`border.badge`, `border.noose`, `border.laurel`, `nameStyle.moonlight/bloodInk/siren`), phone | «Si sblocca con: …» took all the tag's width on one line: the piece's name broke inside words («Il disti / ntivo») and the class tag wrapped («EPIC / O»). | High | On the phone the unlock line is a 150 pt column, three lines of 11.5 pt; the name keeps its room. Desktop was already fine. Test in `shop_screen_test.dart`. |
| bundle `repertorio` (all gestures) | The Vetrina showed a bare bust, its thumbnail too: nothing of what it sells. | High | A bundle of gestures shows them in flight in the hero and two by two on its thumbnail, with no bust/card toggle. Test in `shop_screen_test.dart`. |
| bundle `leggenda` and the frame sets (`insegna_neon`, `bisca`, `giardino`) | Frames and inks bundles opened on the bare bust: nothing visible. | High | They open on the seat card, like a single frame (`bundleAround`, which was written but never used). |
| `border.suits` | The four suits were typed glyphs (♠♥♣♦) with a fallback list of Apple fonts: where the font is missing (Windows/Linux Steam builds, the test renderer) they were empty boxes. | High | The suits are drawn as paths (`SeatFramePainter.suitPath`). |
| all scenes, phone bust view | The scene filled a square wider than the screen and the price tag covered its bottom half: the face was cropped at the mouth, the square's hard edges read as a cut. | High | The wide departments frame the whole portrait above the tag (`_heroFrame`), and the scene is painted as a framed picture: rounded corners, brass rim, a soft shadow (`_ZoomBustPainter.framed`). |
| wings (`back.angelWings`, `batWings`, `butterflyWings`, `dragonWings`, `gildedWings`), phone and desktop | The wings reach past the portrait square: in the hero they were sliced off at the screen/stage edge. | High | Same wider frame on the phone; the desktop frame for these departments zooms out (1.26). |
| `frontFx.yarn`, phone bust view | The ball of yarn sits low on the left: it was hidden under the price tag, the hero looked empty. | High | Fixed by the new frame. |
| all gestures, phone hero | The art sat low in the hero: the price tag covered the bottom of the horse's sheet, the briefcase, the hat's brim. | Medium | The gesture fits in the room above the tag. |
| all gestures, phone hero | The art sat low in the hero: the price tag covered the bottom of the horse's sheet, the briefcase, the hat's brim. | Medium | The gesture fits in the room above the tag. |
| receipt dialog (every piece), phone | Price and «Affare fatto» side by side with «Non ora» in half the card: the label shrank to unreadable small caps. | High | On the phone a two-button dialog whose button carries a price stacks them, the deal on top (`NoirActions`). |
| Mani, phone dial | The Left/Right chips wrapped with the filters: «Destra» alone on a second line. | Medium | The hands have their own row under the filters. |
| gesture target picker, table | Long handles cut: «massimil…», «bartolom…» — you could not tell Massimiliano from Massimiliana. | High | Wider tags (160) and the name shrinks to fit, never cut. |
| `gesture.horse` in the drawer | «Un'offerta che non puoi rifiu…» cut at two lines. | Low | Three lines for a label. |
| frames and inks, phone, bust view | The real app let you switch a frame or an ink to the bust, where it does not show at all: thirteen inks in a row looked identical. | Medium | No bust/card toggle for frames, inks and their bundles: always the seat card. |
| «È tuo: …» notice after a purchase | It sits over the department medallions for its two seconds. | Low | Kept: brief, and it is the app-wide notice. |
| other players' looks in the test backend | `FakeOnline.addPlayer` dropped the look: every seat at the table showed the house face. | Medium (tooling) | The look is remembered like a profile from the server. |
| `aura.inferno` | The flames were tallest in the middle, behind the person; at the table only a red gradient showed, nothing like «Fiamme dell'inferno». | Medium | Flames tallest at the sides, short in the middle. |
| `aura.vesuvio` | Volcano and sun sat low, behind the shoulders: at the table the scene read as a pink gradient. | Medium | Sun, volcano and the sea's line raised beside the head. |
| `frontFx.petals` | Dark, thin petals: invisible at the table. | Medium | Brighter rose, plumper petals with a highlight, bigger at small sizes. |
| `frontFx.fireflies` | At small sizes only two or three dots were drawn and most were skipped around the head. | Medium | All nine fireflies at every size, bigger glow at the table. |
| `frontFx.sparkles`, `frontFx.bats` | Specks at the table. | Low | 1.5× at small sizes, bats with a stronger outline. |
| `nameStyle.bloodInk` | The darkest stops of the gradient vanished on the plate's near-black: unreadable at the table. | Medium | Lighter blood reds. |
| `nameStyle.siren` | The gradient tile was wider than a short name: «UGO» came out all blue, no siren. | Medium | Its own shader: blue at one end, red at the other, any length. |
| frames/inks, phone card view | With a two-line piece name the tag grows and almost touched the seat card's plate. | Low | The card keeps 16 pt more room above the tag. |
| window, featured piece on a 375 pt phone | The timer badge overflowed its row by half a point (layout error in debug). | Low | The time shortens with an ellipsis if the column is that narrow. |
| `held.teddy`, `held.cat` | Held high in both hands, they cover the chin and the cigar. | Low | Kept: they are hugged, by design. |
| `back.batWings` | The little devil tail shows under the price tag in the bust view. | Low | Kept: part of the piece. |
| bundle `ali` | Halo and horns are both hats, four wings one back: the bust shows one of each. | Low | Kept: one piece per slot; the thumbnails of the bundle show them all on the desktop. |
| `gesture.horse`, `gesture.tommy` (legendary) | During the landing pop (≈0.2 s) the art covers the target's name plate. | Low | Kept: brief, and it is the legendary's scene. |
| frame thumbnails | The plate's ends are clipped by the round thumbnail. | Low | Kept: the thumbnail is a medallion; the hero shows the whole card. |

In the real macOS run the green and blue crosshairs on a few table frames
are the test binding marking where it tapped, not the app.

Checked and fine: every held item sits in the hand in both hands and at
the table; every shoulder piece behind the bust; every frame inside its
card at 74 px (test: none reaches more than 12 px past the card); every
gesture readable in flight and on arrival; the desktop's unlock line and
its seat card beside the bust.

## Tests added

- `integration_test/bottega_walk_test.dart`: the player's walk above;
  it fails if a mission-only piece does not say how it unlocks.

- `test/ui/seat_cosmetics_fit_test.dart`: every ink writes a twelve-letter
  handle whole on the 74 px plate; every frame stays within 12 px of its
  card; the suits are paths.
- `test/ui/shop_screen_test.dart`: the gestures bundle shows its gestures,
  the frames bundle the seat card; on a 375 pt phone the unlock line stays
  inside the tag, under half of it, and the piece's name is whole.
