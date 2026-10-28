import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;

import '../steam/steam.dart';

/// The platform mirror of our achievements: Steam, Game Center, Play Games.
///
/// The server is the only judge (internal.player_achievements, written when
/// a game is settled). The phone mirrors to the platform only ids the server
/// has confirmed: the ones `game_unlocks` returns after a game and the ones
/// `my_progress` lists (a sync, for unlocks earned on another device or
/// before the platform was there). Nothing here ever decides an unlock.
///
/// Ids: Steam API name = our id (`role_medico`); Game Center = `oberta.<id>`
/// ([gameCenterId]); Play Games = the id the Play Console generates, from
/// [playGamesIds] (empty: nothing is sent). See docs/steam.md and
/// docs/release.md.
class PlatformAchievements {
  /// The one in use. Without [start] (tests, web, desktop without Steam)
  /// it reports nowhere.
  static PlatformAchievements instance = PlatformAchievements(null);

  /// Picks the backend for this build and device. Never throws and never
  /// waits for a sign-in sheet.
  static Future<void> start() async {
    try {
      instance = PlatformAchievements(_pick());
      instance.backend?.prepare();
    } catch (e) {
      debugPrint('achievements: $e');
    }
  }

  static AchievementBackend? _pick() {
    if (kIsWeb) return null;
    if (SteamClient.enabled && SteamClient.instance.running) return SteamAchievements(SteamClient.instance);
    if (defaultTargetPlatform == TargetPlatform.iOS) return GameCenterAchievements();
    if (defaultTargetPlatform == TargetPlatform.android && playGamesIds.isNotEmpty) return PlayGamesAchievements();
    return null;
  }

  final AchievementBackend? backend;
  final Set<String> _reported = {};
  Future<void> _queue = Future.value();

  PlatformAchievements(this.backend);

  static final _idShape = RegExp(r'^[a-z0-9_]{3,40}$');

  /// Mirrors server-confirmed achievement [ids] to the platform. Idempotent
  /// (an id that went through is not sent again in this run; one that
  /// failed is tried again next time) and never throws.
  Future<void> report(Iterable<String> ids) {
    final backend = this.backend;
    if (backend == null) return Future.value();
    final fresh = {for (final id in ids) if (_idShape.hasMatch(id) && !_reported.contains(id)) id};
    if (fresh.isEmpty) return _queue;
    return _queue = _queue.then((_) async {
      try {
        if (!await backend.ready()) return;
        for (final id in fresh) {
          if (_reported.contains(id)) continue;
          try {
            if (await backend.unlock(id)) _reported.add(id);
          } catch (e) {
            debugPrint('achievements: $id: $e');
          }
        }
      } catch (e) {
        debugPrint('achievements: $e');
      }
    });
  }

  /// The ids already mirrored in this run (for tests and the Steam sheet).
  Set<String> get reported => Set.unmodifiable(_reported);
}

/// One platform. [unlock] says whether the platform now has [id] unlocked
/// (already had it counts); false means try again another time.
abstract class AchievementBackend {
  /// Called once at start, without waiting: a sign-in in the background.
  void prepare() {}

  /// Signed in / attached: worth sending anything.
  Future<bool> ready();

  Future<bool> unlock(String id);
}

/// Steamworks: `SetAchievement` + `StoreStats` through the FFI layer. The
/// API names in Steamworks are our ids, exactly.
class SteamAchievements extends AchievementBackend {
  final SteamClient steam;

  SteamAchievements(this.steam);

  @override
  Future<bool> ready() async => steam.running;

  @override
  Future<bool> unlock(String id) async {
    // null: Steamworks has no achievement with this API name (yet).
    final had = steam.achieved(id);
    if (had == null) return false;
    return had || steam.unlock(id);
  }
}

/// The Game Center id of one of our achievements (App Store Connect →
/// Game Center → Achievements → Achievement ID).
String gameCenterId(String id) => 'oberta.$id';

/// Our id → the id the Play Console generates (`CgkI...`). Empty until the
/// Android release: ids missing here are never sent.
const playGamesIds = <String, String>{};

/// Game Center (iOS), through games_services. Signs in once at start in
/// the background: Game Center shows its own banner or sheet, the app never
/// waits for it.
class GameCenterAchievements extends AchievementBackend {
  Future<bool>? _signIn;

  Future<bool> _signedIn() => _signIn ??= () async {
        try {
          await gs.GameAuth.signIn();
        } catch (_) {
          // Already signed in comes back as a message, a refusal as an error.
        }
        try {
          return await gs.GameAuth.isSignedIn.timeout(const Duration(seconds: 5));
        } catch (_) {
          return false;
        }
      }();

  @override
  void prepare() => unawaited(_signedIn());

  @override
  Future<bool> ready() async {
    final ok = await _signedIn();
    if (!ok) _signIn = null; // signed in later from Settings: ask again next time
    return ok;
  }

  @override
  Future<bool> unlock(String id) async {
    await gs.Achievements.unlock(achievement: gs.Achievement(iOSID: gameCenterId(id)));
    return true;
  }
}

/// Google Play Games (Android), through games_services: only ids in
/// [playGamesIds].
class PlayGamesAchievements extends AchievementBackend {
  Future<bool>? _signIn;

  Future<bool> _signedIn() => _signIn ??= () async {
        try {
          await gs.GameAuth.signIn();
        } catch (_) {}
        try {
          return await gs.GameAuth.isSignedIn.timeout(const Duration(seconds: 5));
        } catch (_) {
          return false;
        }
      }();

  @override
  void prepare() => unawaited(_signedIn());

  @override
  Future<bool> ready() async {
    final ok = await _signedIn();
    if (!ok) _signIn = null;
    return ok;
  }

  @override
  Future<bool> unlock(String id) async {
    final play = playGamesIds[id];
    if (play == null) return true; // not on Play Games: nothing to send, ever
    await gs.Achievements.unlock(achievement: gs.Achievement(androidID: play));
    return true;
  }
}
