# QA report: end-to-end flows

Date: 2026-10-29. Base: `main` at `5f23c88`, rebased before the final runs. Report only: no code was changed.

## How it was tested

- **Real app on macOS** (`flutter test integration_test/... -d macos`). This is the real `ObertaApp`, driven by real taps from the home screen with real time and real fonts. The backend is `FakeOnline` with bots and shortened pacing. Only one app instance ran at a time, under `/tmp/oberta_app.lock`. Phone, iPad and desktop layouts were obtained by overriding the view size (`DesktopPlatform.debugOverride` for desktop). The iOS simulator was not used, to keep to the one-app rule.
  - Online friends room: home poster, "Apri una stanza", a second person joins, start, a full game, the end screen, the recap, then results with XP, coins and the mission toast. Covered at 4, 8 and 12 seats on 393x852, 375x667, iPad 820x1180 and desktop 1920x1080.
  - Leaving mid-game: the X button, the "Abbandonare la partita?" dialog, then "Esci".
  - Reconnect: the network dropped for 12 s and came back, then the app went to the background for 8 s and returned to the foreground.
  - Local one-phone game: "Crea stanza", "+ TEST" players, automatic narrator, the cards, then nights, days, votes and the final screen. Covered at 4, 6, 8 (on 375x667) and 12 seats.
  - All three tutorials (family, town, solo), opened from the street sign and played to "Ora sei pronto".
  - Frame build times came from `addTimingsCallback`, grouped by phase.
- **Headless widget flows** using the real `OnlineGameScreen` and `FakeOnline` with a manual clock:
  - Every role was seated on the player's own seat with a seeded deal: 28 roles at 12 seats, plus the Cecchino at 8 seats (the Cecchino is not dealt at 12).
  - A matrix of 4–12 seats × the 4 screen sizes × it/en, with meme mode on for even seat counts: 72 games.
  - Each run collected every `FlutterError` (overflows, setState after dispose), stuck phases, leak markers (chat tabs and jail/lovers markers per role) and wrong-language strings.
- **Server scan:** 1,200 `ServerGame.deal` tables with bots (4, 8 and 12 seats, plus the ranked deck at 12), stepped with a 2 s tick as in production.
- **Baseline:** `flutter test` passed all 1265 tests before any of this.

The scratch harness is not committed: `integration_test/qa_app_test.dart`, `test/qa/*.dart`, and a local `integration_test` dev dependency that was reverted afterwards.

Screenshots are in `/private/tmp/claude-501/-Users-nicolai-code-Lupus/40086ece-873c-406e-a9b3-39fa51b6bffb/scratchpad/qa_shots/`. They are not in the repo.

## Summary

| | Result |
|---|---|
| Crashes / FlutterErrors in 101 headless games | **0**: no RenderFlex overflow, no setState after dispose |
| Real app: errors | 1 recurring exception (P2-1) |
| Stuck states | none in the app. The fake server freezes under a manual clock because of P1-1 |
| Info leaks | none found. The family tab shows only for family roles and never for the Prostituta; the lovers marker only for lovers; the jail markers only for the jailer and the prisoner |
| Wrong-language strings | none: no Italian in English rooms, no English in Italian rooms (place names excepted) |
| All phases reached | reveal, night, film, dawn, discussion, vote, verdict, end, plus recap and results |
| Day powers | Artigliere fire (2 shots), Tiratore shot, Pacifista truce, Sindaco reveal: all accepted, all with their confirmation dialog |
| Sect | conversion works: the Capo's sect grew to 2 |

## P0: crash / stuck

None found in the app.

## P1: wrong rules / server

### P1-1: A bot Sindaco who reveals himself never votes, and the server asks to be woken in 1970 for the rest of the vote

- **What happens:** `BotBrain` sometimes answers the vote with `RevealMayor` (`lib/online/game/bot_brain.dart:112`). `_botActs` applies it and marks the bot as done with an epoch-0 time (`lib/online/game/game_server.dart:941-947`). Revealing does not add a day vote, so `_botWaiting` stays true (`game_server.dart:902-910`). `_scheduleBots` therefore never removes the marker, and `nextDue()` takes the epoch-0 entry as the soonest time (`game_server.dart:686-697`).
- **Effects:**
  1. **Rules:** the bot Sindaco loses his own vote that day, which is the vote that now counts double.
  2. **Production load:** `next_due_at` becomes 1970, so `internal.game_tick` re-steps this game on every 2 s tick until the vote deadline. That is about 15–30 useless edge calls each time it happens.
  3. **Fake server:** with `SystemGameClock` the timer re-arms at `Duration.zero`, a busy loop until the deadline. With `ManualClock` time never advances: `fireNext` keeps firing the same past-due timer.
- **How often:** 19 of 300 friends tables at 12 seats with bots, and 47 of 300 ranked-deck tables at 12 seats with bots. It was never seen at 4 or 8 seats.
- **Repro:**
  - Run `test/qa/server_livelock_qa_test.dart`, for example 12 seats with seed 6: `botDue={s9: 1970-01-01}`, s9 is the Sindaco, `voted=false`.
  - In the UI: the online run with the player as Prostituta (seed 26), round 3 vote. The clock freezes at 21:05:57 with the deadline at 21:06:14.
- **Suspects:** `_botActs` should cast a vote after the reveal (or let the brain vote on its next turn). Separately, `nextDue()` should skip epoch-0 entries.

## P2: visible bugs

### P2-1: `AnimationController.reverse() called after AnimationController.dispose()` when the finger is still on the role card as the reveal ends

- **Where:** `lib/ui/screens/online/game/noir_role_card.dart:91-98`. The `Listener.onPointerUp/onPointerCancel` callback calls `_release()` → `_flip.reverse()` after the state has been disposed. The pointer route keeps the old render object.
- **Seen:** 5 of the 9 real-app online runs: phone 4 seats, iPad 8 seats, leave, reconnect, and the first batch.
- **Repro:** in an online game, hold the card until the reveal window closes and the night replaces it, then lift the finger. The gesture library reports the exception. In release it becomes a null-check error in the pointer handler.
- **Fix direction:** `if (!mounted) return;` in `_release` (and in `_press`).

### P2-2: A closed game shows "Il server non risponde: controlla la connessione. RIENTRA" under "La partita è stata chiusa"

- **Where:** `lib/ui/screens/online/online_game_screen.dart:530-535`. `_serverSilent` excludes `Stage.ended` but not `_board.abandoned`. After an idle close the window stays at the last vote or night, so 12 s later the connection banner appears with a "Rientra" button that cannot help.
- **Repro:** an online game where every human stops acting (the player is dead and the other human never taps). After `idleTimeouts` the server closes the game, and the banner appears on top of the closed view. Seen at 375x667, iPad and desktop.
- **Screenshots:** `qa_shots/online_phone375_12_timeout.png` and `qa_shots/online_desktop_12_timeout.png`.

### P2-3: On the results screen, the mission toast covers the "VITTORIA" headline

- **Where:** `showMatchResults` in `lib/ui/screens/online/match_results_screen.dart:46-56`. `ProgressToasts` is stacked over `MatchResultsScreen`, and at 393x852 the "Missione compiuta: Vinci una partita. Riscuotila!" banner sits right on the title.
- **Screenshot:** `qa_shots/online_phone393_8_results.png`.

## P3: polish, performance, test fidelity

### P3-1: Day phases rebuild far more than the night (debug build, needs a profile-mode check)

- **Measured on the real macOS app (debug), frame build time in ms, p50 / p90 / max:**

  | Phase | 8 seats (phone) | 12 seats (desktop) |
  |---|---|---|
  | night | 0.25 / 17 / 67 | 22 / 27 / 62 |
  | discussion | 19 / 32 / 68 | 24 / 35 / 84 |
  | vote | 22 / 29 / 61 | 26 / 38 / 97 |
  | verdict | 20 / 29 / 93 | 27 / 33 / 86 |

  Most frames in these phases are over 8 ms. Debug mode inflates build cost several times, so the 8 ms target cannot be judged from this run. The gap between night and day on the same table is still large.
- **Headless steady state:** discussion frames cost about 0.03 ms (no rebuild per frame), so the cost comes from what changes every second: the countdown, the chat and the reactions.
- **Suggestion:** a profile run on a device, looking at `StageHeader`, the countdown and `ChatDock` rebuilding the whole `SaloonTable`.

### P3-2: Losing the network is silent until 12 s after the phase deadline

- **Where:** `GameClient._ping` swallows errors (`lib/online/game/game_client.dart:154-172`). "Sembri offline" needs a server update, which cannot arrive while the phone is offline. The only local cue is `_serverSilent`, 12 s after the window ends.
- **Observed:** after 12 s offline, no banner was showing (`qa_shots/reconnect_offline.png`, taken during a film). After the network came back and after 8 s in the background, the game resumed (`resume()` called once) and finished normally.

### P3-3: `FakeOnline` never deals the ranked deck

- **Where:** `_serve` (`lib/online/fake_online.dart:1133-1147`) does not pass `'ranked'` to `serverStep`. The real runner does (`supabase/functions/game/runner.ts:98`). Every fake-driven ranked UI test therefore plays the friends deck.

### P3-4: Test harness hang (fake only, low confidence)

- **What happens:** in a widget test, subscribing to `FakeGame.watchGame` once, cancelling it, and then pumping again (`pumpWidget(OnlineGameScreen)`, or creating a second `FakeOnline` and calling `setBots`) never returns, with the CPU at 100%.
- **What is known:** it did not reproduce without the extra subscribe/cancel. The cause was not isolated. It is worth knowing for anyone writing seed-search tests.

### By design, not bugs

- A room's game screen follows the room's language, not the app's: an English app in an Italian room shows Italian (`online_game_screen.dart:124-161`).
- The dawn film shows the death card full screen, so connection banners are hidden behind it.

## Coverage gaps

- **iOS simulator:** not run, to respect the one-app rule. The macOS app was used instead.
- **Real ranked with 12 humans:** the fake needs 12 accounts. Ranked was covered only through server-level scans (P1-1) and the test-match path.
- **Jail chat, lovers chat, heartbreak:** the jail chat and lovers chat were not typed into from the UI, and heartbreak was not seen in a UI run. Server rules are covered by `test/online/blockers_server_test.dart`, `test/rules/cupid_test.dart` and `test/rules/sect_test.dart`.
- **Missions board:** opening it after a game needs the alley, and the harness could not find its way back from the room screen. The mission toast and the claim prompt were seen on the results screen.
- **Leaving as a living player:** the abandon was not checked on the fake server, because presence tracking was off in that run. The dialog, the warning text and the exit itself work (`qa_shots/leave_dialog.png`).
