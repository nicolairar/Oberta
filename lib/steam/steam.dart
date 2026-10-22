import 'package:flutter/foundation.dart';

import 'steam_ffi.dart';

/// Lo strato Steamworks, sottile e facoltativo (docs/steam.md, 1.8 e 2.3).
///
/// C'è solo nelle build compilate con `--dart-define=STEAM=true`: senza,
/// [SteamClient.instance] è [NoSteam] e l'app non apre nessuna libreria
/// Steam, esattamente come prima. Con il flag, [SteamClient.start] prova a
/// caricare `steam_api64.dll` / `libsteam_api.so` / `libsteam_api.dylib`
/// accanto all'eseguibile e ad agganciarsi al client Steam aperto; se non
/// c'è (libreria mancante, Steam chiuso) resta [NoSteam] e basta.
abstract class SteamClient {
  /// Compilato con `--dart-define=STEAM=true`.
  static const enabled = bool.fromEnvironment('STEAM');

  /// L'App ID con cui si prova in sviluppo: 480 (Spacewar, di Valve) finché
  /// non c'è il nostro. Una build Steam vera lo prende da Steam stesso.
  static const devAppId = int.fromEnvironment('STEAM_APP_ID', defaultValue: 480);

  /// L'identità che il server si aspetta nei biglietti per la Web API
  /// (`steam-auth`, azione `ticket`).
  static const webApiIdentity = 'oberta';

  static SteamClient instance = const NoSteam();

  /// Da chiamare una volta all'avvio. Senza il flag non fa niente.
  static Future<void> start() async {
    if (!enabled || kIsWeb) return;
    instance = FfiSteam.tryOpen(appId: devAppId) ?? NoSteam(FfiSteam.lastProblem);
  }

  const SteamClient();

  /// Agganciato a un client Steam aperto e con un utente entrato.
  bool get running;

  /// Perché non è agganciato (per il menu di prova); null se va.
  String? get problem;

  /// Lo SteamID64 dell'utente Steam entrato.
  int? get steamId;

  /// Il nome (persona) dell'utente Steam: solo da mostrare nel menu di
  /// prova o da proporre, mai come nome unico senza le nostre regole.
  String? get personaName;

  /// Un biglietto per la Web API (`GetAuthTicketForWebApi`), da mandare al
  /// server che lo verifica con `ISteamUserAuth/AuthenticateUserTicket`.
  /// Null se Steam non c'è o non risponde in tempo.
  Future<Uint8List?> webApiTicket(String identity, {Duration timeout = const Duration(seconds: 10)});

  /// Traguardi Steam (con 480 solo quelli di Spacewar).
  bool? achieved(String name);
  bool unlock(String name);
  bool clear(String name);

  void shutdown();
}

/// Nessuno Steam: la build normale, o Steam non trovato.
class NoSteam extends SteamClient {
  @override
  final String? problem;

  const NoSteam([this.problem]);

  @override
  bool get running => false;
  @override
  int? get steamId => null;
  @override
  String? get personaName => null;
  @override
  Future<Uint8List?> webApiTicket(String identity, {Duration timeout = const Duration(seconds: 10)}) async => null;
  @override
  bool? achieved(String name) => null;
  @override
  bool unlock(String name) => false;
  @override
  bool clear(String name) => false;
  @override
  void shutdown() {}
}

/// I traguardi fissi di Spacewar (App ID 480): servono solo a provare
/// l'idraulica, non sono i nostri.
const spacewarAchievements = [
  'ACH_WIN_ONE_GAME',
  'ACH_WIN_100_GAMES',
  'ACH_TRAVEL_FAR_ACCUM',
  'ACH_TRAVEL_FAR_SINGLE',
];

/// Il biglietto in esadecimale, come lo vuole la Web API di Steam.
String ticketHex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
