# Skin audit: Abito, Vizio, Calcio, whole looks

Every suit, dress and costume (50), every vice (38), every football piece (40: kits, bobble hats, scarves, flares, megaphones, trophies, flags) and every whole look (23 bundles, plus the gold statue alone, with the crown, over a tuxedo and cigar, over a kit and scarf) was drawn on three players: a light-skinned man with an oval face, a dark-skinned woman with a round face in a dress, and a bearded man with a square face and curly hair. Each was drawn three ways: on the shop's hero bust (framed as on a 393 pt phone, with the price tag's band shaded), as the shop's round thumbnail (73 and 53 pt), and on the table's 74 pt seat card. That is 155 rows in all.

Sheets: `flutter test tool/audit/skins_render_test.dart` writes `build/audit/skins/{abito,vizio,calcio,looks}_N.png` at dpr 3, 20 items per sheet, each row labelled with its item id. `ONLY=id,id` renders just those rows.

The checks that can be automated live in `test/ui/skin_rules_test.dart`.

| Item id | Problem | Severity | Fix |
|---|---|---|---|
| outfit.gold_brocade, outfit.versalli_baroque, face.goldStatue, bundle.versalli, bundle.leggende | The gold shine was a hard-edged square of light over the whole picture, background and face included. In the shop hero its top and right edges were cut straight. | High | The shine is clipped to the gold: the statue's head and hair, or the gold suit's torso (`noir_painter.dart`, `gilt`). |
| accessory.tie, polkaTie, stripeTie, knitTie, ricciTiePin (and the tie under vaugirardStrap) | Invisible on any woman: the painter skipped ties when the player presents as a woman. Bought, tried on, and nothing changed. | High | Ties show for everyone. They are only skipped under a zip or a costume, which have no collar (`look_painter.dart`, `_neck`). |
| accessory.tie, scarf, cravat on rose/emerald/black dress | The neckwear took the dress's pale trim colour, so it came out as a washed-out grey-beige smear on the skin. | Medium | On a dress with a pale accent, neckwear is deep navy (wine on the black dress). |
| every accessory.*Flare/*Megaphone/*Trophy/*Flag | The stadium glow went through the ink outline pass, so a dark disc with a hard rim sat behind the player. In the hero it read as a coin cut by the frame. | High | The outline pass skips the glow and the smoke (`_Calcio.glow`); only the pole and the flag get outlined. |
| accessory.nerazzurriFlag, azzurriFlag | A small two-colour square floated beside the shoulder at the hem: the "hand" was drawn in the mouth-prop space, away from the pole. | High | It is now a ribbon knotted on the pole above the shoulder, drawn with the flag. |
| all calcio props, parrot, pigeon, balloons, snailShell, jetpack, plungerSword, baguetteCigar | The thumbnail zoomed on the face, so the item (at the side of the portrait) was cut off. At 53 pt the flare was a sliver. | Medium | `LookPainter.beside` marks these, and their thumbnail shows the whole portrait (`shop_parts.dart`, `_focusOf`). |
| all costumes drawn by the legacy coat (clown, strongman, mime, magician, chef, banana, pizza, cactus, ghost, mummy, fulmine/adelphi, vaugirard_travel, gold_brocade, versalli_baroque, delacroix_cape) | The tailored suit's outline was still drawn under the costume. It showed as black shoulder pads outside the costume and a thin line across the chest. | High | That outline is drawn only for tailored suits. A costume keeps its own dilated outline. |
| ghost_sheet, mummy_wraps, banana_suit, pizza_suit, cactus_suit (women) | A dark V-neck was cut into the sheet, bandages or fruit. | Medium | Full-body costumes skip the dress V-neck and get the costume's own collar. |
| outfit.mummy_wraps | A flat grey box floated at the throat. | Medium | It is now a rounded neck wrap with two bandage lines and an outline. |
| every tie, suspenders, chanterellePearls, cravat on tailored suits; lapel tips | They hung below the jacket hem wherever the bust is drawn whole. | Low | The neck layer is clipped at the hem on tailored suits (checked by a test). |
| outfit.navy_double, midnight_double, oxblood_double, bundle.padrino | The double-breasted buttons sat below the hem, as two loose dots. | Medium | Moved up beside the bottom of the vee, inside the jacket. |
| men in a dress or blouse (accessory none, cigars, props) | Shirt-collar points showed on a dress neckline. | Low | No open shirt collar on a dress, a blouse or a jersey. |
| outfit.diavoli_kit (and its cap, scarf, flare) | The collar was white, but the tagline says "Fire red, black collar". | Medium | Diavoli's secondary and trim colours are swapped: black collar, white second colour. |
| accessory.toothpick | Under a pixel wide on the 74 pt seat card, so it disappeared at the table. | Medium | It is longer and keeps at least about one pixel of wood at small sizes. |
| bundle.curva_* | Only cap, kit and scarf show; the flare, trophy or flag is the second vice and the shop wears one per slot. | Low | Not changed: it follows the shop's one-piece-per-slot rule. Noted for the shop owner. |
| outfit.pizza_suit | Reads as a yellow box with pepperoni rather than a slice. | Low | Not redrawn in this pass. |
| face.fullBeard (base of player C) | A tan line runs from the ear to the mouth along the beard edge. | n/a | Barber/face scope: left to that audit. |

Checked after two rounds of rendering: all the rows above look right on all three players, in all three views. No labels overlap the card or the name plate in any row, and every scarf, cap and kit shows its team's colours.
