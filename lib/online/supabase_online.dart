import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/lobby_language.dart';
import '../rules/intent.dart';
import 'incoming_links.dart';
import 'online_config.dart';
import 'online_services.dart';
import 'steam_login.dart';
import 'voice/supabase_voice.dart';
import '../steam/steam.dart';

/// L'online vero, su Supabase. Lo apre `main` quando l'app è stata compilata
/// con la configurazione; i test usano invece `FakeOnline`.
Future<OnlineServices?> openSupabaseOnline(
  OnlineConfig config, {
  String? deviceSessionId,
  int? appBuild,
  String? appPlatform,
}) async {
  if (!config.isComplete) return null;
  try {
    // Ogni chiamata porta la sessione di questo dispositivo: il server lascia
    // scrivere solo quella attiva (un dispositivo alla volta).
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      // Build e piattaforma: il server rifiuta le build troppo vecchie con
      // `update_required` (20261103090000_mandatory_update.sql).
      headers: {
        'x-device-session': ?deviceSessionId,
        'x-app-build': ?appBuild?.toString(),
        'x-app-platform': ?appPlatform,
      },
    );
  } catch (error) {
    debugPrint('Supabase non disponibile: $error');
    return null;
  }
  final client = Supabase.instance.client;
  final game = SupabaseGame(client);
  return OnlineServices(
    auth: SupabaseAuth(client, config),
    profiles: SupabaseProfiles(client),
    friends: SupabaseFriends(client),
    rooms: SupabaseRooms(client),
    game: game,
    shop: SupabaseShop(client),
    ranked: SupabaseRanked(client),
    account: SupabaseAccount(client),
    safety: SupabaseSafety(client),
    sessions: SupabaseDeviceSessions(client),
    links: SupabaseAccountLinks(client, config),
    progress: SupabaseProgress(client),
    requirements: SupabaseAppRequirements(client),
    reactions: SupabaseReactions(client, game),
    voice: SupabaseVoiceTokens(client),
  );
}

/// Da che porta si stava entrando: dice quale provider manca, se manca.
enum SignInDoor { apple, google, email }

/// Il motivo tecnico di un errore, corto e leggibile: codice e messaggio.
String? technicalReason(Object error) => switch (error) {
      OnlineException(:final reason) => reason,
      AuthException(:final code, :final statusCode, :final message) =>
        [?code, ?statusCode, message].join(' · '),
      PostgrestException(:final code, :final message) => [?code, message].join(' · '),
      SignInWithAppleAuthorizationException(:final code, :final message) => 'apple ${code.name} · $message',
      SignInWithAppleException() => 'apple · $error',
      GoogleSignInException(:final code, :final description) => ['google ${code.name}', ?description].join(' · '),
      _ => error.toString(),
    };

/// Un errore di accesso di Supabase, nelle parole della UI.
OnlineFailure? _authFailure(AuthException error, SignInDoor? door) {
  final code = error.code ?? '';
  final message = error.message.toLowerCase();
  final disabled = code == 'provider_disabled' ||
      code == 'email_provider_disabled' ||
      code == 'signup_disabled' ||
      message.contains('provider is not enabled') ||
      message.contains('unsupported provider') ||
      message.contains('logins are disabled') ||
      message.contains('signups not allowed');
  if (disabled) {
    return switch (door) {
      SignInDoor.google => OnlineFailure.googleDisabled,
      SignInDoor.email => OnlineFailure.emailDisabled,
      _ => OnlineFailure.appleDisabled,
    };
  }
  if (code == 'email_address_invalid' || message.contains('unable to validate email')) {
    return OnlineFailure.invalidEmail;
  }
  // «Entra con email»: il server non distingue un codice sbagliato da uno
  // scaduto (`otp_expired` per tutti e due); lo decide verifyEmailCode.
  if (code == 'otp_expired' || message.contains('token has expired or is invalid')) {
    return OnlineFailure.emailCodeWrong;
  }
  if (door == SignInDoor.email) {
    if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit' || error.statusCode == '429') {
      return OnlineFailure.emailRateLimited;
    }
    // La mail la manda la funzione `auth-email` (Send Email Hook): se non
    // risponde o Brevo la rifiuta, Supabase dice «Error sending ... email».
    if (code.startsWith('hook_') || message.contains('error sending')) return OnlineFailure.emailNotSent;
  }
  if (error is AuthRetryableFetchException) return OnlineFailure.network;
  return null;
}

/// Traduce gli errori del server nelle parole della UI. Le funzioni del
/// database alzano eccezioni col nome del problema (`room_full`, ...).
/// Il motivo tecnico resta attaccato, e finisce anche nel log.
OnlineException translateOnlineError(Object error, [SignInDoor? door]) => _translate(error, door);

OnlineException _translate(Object error, [SignInDoor? door]) {
  if (error is OnlineException) return error;
  final translated = _classify(error, door);
  if (translated.failure == OnlineFailure.otherDevice) DeviceSession.instance?.otherDeviceRejected();
  if (translated.failure == OnlineFailure.updateRequired) UpdateGate.instance?.serverRejected();
  debugPrint('Online: ${translated.failure.name} ← ${translated.reason}');
  return translated;
}

OnlineException _classify(Object error, SignInDoor? door) {
  final detail = technicalReason(error);
  if (error is AuthException) {
    return OnlineException(_authFailure(error, door) ?? OnlineFailure.unknown, error, detail);
  }
  if (error is PostgrestException) {
    if (error.code == '23505') return OnlineException(OnlineFailure.handleTaken, error, detail);
    if (error.code == '23514') return OnlineException(OnlineFailure.invalidHandle, error, detail);
    final failure = switch (error.message) {
      'not_signed_in' => OnlineFailure.notSignedIn,
      'profile_incomplete' => OnlineFailure.profileIncomplete,
      'handle_not_allowed' => OnlineFailure.handleNotAllowed,
      'room_not_found' => OnlineFailure.roomNotFound,
      'room_closed' => OnlineFailure.roomClosed,
      'room_full' => OnlineFailure.roomFull,
      'host_must_choose' => OnlineFailure.hostMustChoose,
      'player_not_found' => OnlineFailure.playerNotFound,
      'not_allowed' || 'profile_blocked' => OnlineFailure.notAllowed,
      'profile_not_found' => OnlineFailure.playerNotFound,
      'request_not_found' => OnlineFailure.requestNotFound,
      'invalid_seats' || 'not_your_seat' || 'stale_version' || 'too_many_intents' => OnlineFailure.notAllowed,
      'not_enough_coins' => OnlineFailure.notEnoughCoins,
      'already_owned' || 'already_claimed' => OnlineFailure.alreadyOwned,
      'mission_only' || 'not_completed' => OnlineFailure.notAllowed,
      'mission_not_found' => OnlineFailure.itemNotFound,
      'not_owned' => OnlineFailure.notOwned,
      'item_not_found' || 'tone_required' || 'bad_slot' => OnlineFailure.itemNotFound,
      'message_blocked' => OnlineFailure.messageBlocked,
      'too_many_messages' => OnlineFailure.tooManyMessages,
      'reaction_closed' => OnlineFailure.reactionClosed,
      'reaction_cooldown' => OnlineFailure.reactionCooldown,
      'reaction_cap' => OnlineFailure.reactionCap,
      'too_many_reports' => OnlineFailure.tooManyReports,
      'invalid_report' => OnlineFailure.notAllowed,
      'silenced' || 'chat_closed' || 'invalid_message' => OnlineFailure.chatClosed,
      'ranked_cooldown' => OnlineFailure.rankedCooldown,
      'tutorials_required' => OnlineFailure.tutorialsRequired,
      'already_in_game' => OnlineFailure.alreadyInGame,
      'other_device' => OnlineFailure.otherDevice,
      'update_required' => OnlineFailure.updateRequired,
      'link_same_account' => OnlineFailure.linkSameAccount,
      'link_conflict' => OnlineFailure.linkConflict,
      _ => OnlineFailure.unknown,
    };
    return OnlineException(failure, error, detail);
  }
  if (error is SocketException || error is TimeoutException) {
    return OnlineException(OnlineFailure.network, error, detail);
  }
  return OnlineException(OnlineFailure.unknown, error, detail);
}

Future<T> _guard<T>(Future<T> Function() call, [SignInDoor? door]) async {
  try {
    return await call();
  } catch (error) {
    throw _translate(error, door);
  }
}

/// Le colonne pubbliche di un profilo: livello, esperienza e monete no,
/// quelle le legge solo il padrone con `my_profile()`.
const _profileColumns = 'id, handle, language, avatar, on_steam, on_apple, picture_url';

/// Un valore casuale da usare una volta sola: Supabase controlla che il
/// token di Apple o Google porti la sua impronta, così un token rubato non
/// si può riusare altrove.
String _rawNonce() {
  final random = Random.secure();
  return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
}

String _sha256(String text) => sha256.convert(utf8.encode(text)).toString();

/// Esce dall'account: prima col server ([remote]); se non risponde entro
/// [timeout], o sbaglia, solo da questo telefono ([local], senza rete).
/// Uscire funziona sempre.
@visibleForTesting
Future<void> signOutOrLocal(
  Future<void> Function() remote,
  Future<void> Function() local, {
  Duration timeout = SupabaseAuth.signOutTimeout,
}) async {
  try {
    await remote().timeout(timeout);
  } catch (_) {
    await local();
  }
}

class SupabaseAuth extends OnlineAuth {
  final SupabaseClient _client;
  final OnlineConfig _config;
  late final StreamSubscription<AuthState> _changes;
  String? _suggestedName;

  /// Google vuole essere preparato una volta sola per tutta la vita
  /// dell'app, e il nonce si passa lì: quello resta per la sessione.
  String? _googleNonce;

  SupabaseAuth(this._client, this._config) {
    // Un link della mail che non va (scaduto, già usato, aperto su un altro
    // dispositivo) arriva qui come errore: lo dice il foglio dell'accesso.
    _changes = _client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      onError: (Object error) {
        final failure = _translate(error, SignInDoor.email);
        _emailLinkFailure = OnlineException(OnlineFailure.emailLinkExpired, failure.cause, failure.reason);
        notifyListeners();
      },
    );
  }

  OnlineException? _emailLinkFailure;

  @override
  OnlineException? takeEmailLinkFailure() {
    final failure = _emailLinkFailure;
    _emailLinkFailure = null;
    return failure;
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get appleAvailable => !kIsWeb && (Platform.isIOS || (Platform.isMacOS && _macAppleSignIn));

  /// Sign in with Apple sull'app Mac vuole la capability nel profilo di
  /// firma del target macOS: finché il proprietario non la aggiunge, la
  /// build Mac entra solo con Steam (vedi docs/steam.md).
  static const _macAppleSignIn = bool.fromEnvironment('MAC_APPLE_SIGN_IN');

  @override
  bool get googleAvailable => !kIsWeb && (Platform.isIOS ? _config.hasGoogle : Platform.isAndroid && _config.hasGoogleAndroid);

  @override
  String? get suggestedName => _suggestedName;

  @override
  bool get steamAvailable => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Il browser porta a Steam e torna sulla porta di loopback con un codice
  /// monouso; la Edge Function `steam-auth` lo scambia con un token di
  /// accesso, e da lì la sessione è quella solita di Supabase (salvata:
  /// i prossimi avvii entrano da soli).
  @override
  Future<void> signInWithSteam() => _guard(() async {
        // Fase 2: dentro Steam basta il biglietto, niente browser. Finché il
        // server non ha la chiave da editore risponde 501 not_configured e
        // si passa a OpenID come sempre.
        if (await _steamTicketSignIn()) return;
        final state = SteamLoopback.newState();
        final functionUrl = Uri.parse('${_config.supabaseUrl.replaceAll(RegExp(r'/$'), '')}/functions/v1/steam-auth');
        final code = await SteamLoopback.waitForCode(functionUrl: functionUrl, state: state);
        final response = await _client.functions.invoke('steam-auth', body: {
          'action': 'exchange',
          'code': code,
          'state': state,
        });
        final tokenHash = (response.data as Map?)?['token_hash'] as String?;
        if (response.status != 200 || tokenHash == null) {
          throw OnlineException(OnlineFailure.unknown, null, 'steam-auth · ${response.status} · ${response.data}');
        }
        await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
      });

  /// Il login col biglietto Steam (`GetAuthTicketForWebApi`), verificato
  /// da `steam-auth` con `AuthenticateUserTicket` e il possesso del gioco.
  /// Falso (si prova OpenID) se Steam non c'è o il server non è pronto.
  Future<bool> _steamTicketSignIn() async {
    final steam = SteamClient.instance;
    if (!steam.running) return false;
    final ticket = await steam.webApiTicket(SteamClient.webApiIdentity);
    if (ticket == null) return false;
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke('steam-auth', body: {'action': 'ticket', 'ticket': ticketHex(ticket)});
    } on FunctionException catch (error) {
      if (error.status == 501) return false; // not_configured: fallback a OpenID.
      if (error.status == 403) {
        throw OnlineException(OnlineFailure.unknown, null, 'steam-auth · ticket · ${error.details}');
      }
      debugPrint('steam-auth ticket · ${error.status} · ${error.details}');
      return false;
    }
    final tokenHash = (response.data as Map?)?['token_hash'] as String?;
    if (tokenHash == null) return false;
    await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
    return true;
  }

  @override
  Future<void> signInWithApple() => _guard(() async {
        final rawNonce = _rawNonce();
        final AuthorizationCredentialAppleID credential;
        try {
          credential = await SignInWithApple.getAppleIDCredential(
            scopes: const [AppleIDAuthorizationScopes.fullName],
            nonce: _sha256(rawNonce),
          );
        } on SignInWithAppleAuthorizationException catch (error) {
          if (error.code == AuthorizationErrorCode.canceled) throw const OnlineException(OnlineFailure.cancelled);
          rethrow;
        }
        final idToken = credential.identityToken;
        if (idToken == null) throw const OnlineException(OnlineFailure.unknown);
        // Apple dà il nome solo al primo accesso: va tenuto adesso.
        final name = [credential.givenName, credential.familyName].whereType<String>().join(' ').trim();
        if (name.isNotEmpty) _suggestedName = name;
        await _client.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: rawNonce);
      }, SignInDoor.apple);

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final google = GoogleSignIn.instance;
        var rawNonce = _googleNonce;
        if (rawNonce == null) {
          rawNonce = _rawNonce();
          // Android non ha un clientId: l'app la riconosce Google dal
          // pacchetto e dalla SHA-1 della firma.
          await google.initialize(
            clientId: Platform.isIOS ? _config.googleIosClientId : null,
            serverClientId: _config.googleWebClientId,
            nonce: _sha256(rawNonce),
          );
          _googleNonce = rawNonce;
        }
        final GoogleSignInAccount account;
        try {
          account = await google.authenticate(scopeHint: const ['email', 'profile']);
        } on GoogleSignInException catch (error) {
          if (error.code == GoogleSignInExceptionCode.canceled) throw const OnlineException(OnlineFailure.cancelled);
          rethrow;
        }
        final idToken = account.authentication.idToken;
        if (idToken == null) throw const OnlineException(OnlineFailure.unknown);
        final authorization = await account.authorizationClient.authorizationForScopes(const ['email', 'profile']);
        if (account.displayName case final name? when name.trim().isNotEmpty) _suggestedName = name.trim();
        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: authorization?.accessToken,
          nonce: rawNonce,
        );
      }, SignInDoor.google);

  /// Dove torna il link della mail: `oberta://` lo conoscono l'iPhone
  /// (Info.plist) e Android (AndroidManifest); è nella lista dei ritorni
  /// ammessi di Supabase (`oberta://**`). supabase_flutter lo riceve da
  /// app_links e scambia il `code` (PKCE) con la sessione da solo.
  static const emailRedirect = 'oberta://login-callback';

  @override
  bool get emailAvailable => true;

  @override
  bool get emailLinkOpensApp => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Quando è partita l'ultima mail per ogni indirizzo: per dire «scaduto».
  final _emailSentAt = <String, DateTime>{};

  static String _address(String email) => email.trim().toLowerCase();

  @override
  Future<void> sendEmailCode(String email, {String? language}) => _guard(() async {
        final address = _address(email);
        await _client.auth.signInWithOtp(
          email: address,
          // Solo per chi entra la prima volta: la lingua delle sue mail.
          data: {'lang': ?language},
          // Sul computer niente link: la mail porta solo il codice (la
          // funzione auth-email mette il pulsante solo per `oberta://`).
          emailRedirectTo: emailLinkOpensApp ? emailRedirect : null,
        );
        _emailSentAt[address] = clock.now();
      }, SignInDoor.email);

  @override
  Future<void> verifyEmailCode({required String email, required String code}) async {
    final address = _address(email);
    try {
      await _guard(() => _client.auth.verifyOTP(type: OtpType.email, email: address, token: code.trim()), SignInDoor.email);
    } on OnlineException catch (error) {
      final sent = _emailSentAt[address];
      final old = sent != null && clock.now().difference(sent) > OnlineAuth.emailCodeLifetime;
      if (error.failure == OnlineFailure.emailCodeWrong && old) {
        throw OnlineException(OnlineFailure.emailCodeExpired, error.cause, error.reason);
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _guard(() async {
        // Il server che non risponde (o la rete che non c'è) non tiene mai
        // dentro l'account: dopo qualche secondo si esce da questo telefono
        // soltanto, che non chiede niente alla rete.
        await signOutOrLocal(
          () => _client.auth.signOut(),
          () => _client.auth.signOut(scope: SignOutScope.local),
        );
        if (_googleNonce != null) {
          try {
            await GoogleSignIn.instance.signOut().timeout(signOutTimeout);
          } catch (_) {}
        }
      });

  /// Quanto si aspetta il server all'uscita dall'account.
  static const signOutTimeout = Duration(seconds: 5);

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }
}

class SupabaseProfiles implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfiles(this._client);

  String get _me => _client.auth.currentUser?.id ?? (throw const OnlineException(OnlineFailure.notSignedIn));

  @override
  Stream<Wallet> watchWallet() {
    final me = _me;
    late final StreamController<Wallet> controller;
    RealtimeChannel? channel;
    controller = StreamController<Wallet>(
      onListen: () {
        channel = _client
            .channel('wallet:$me')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'wallets',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'profile_id', value: me),
              callback: (change) {
                if (change.newRecord.isEmpty || controller.isClosed) return;
                controller.add(Wallet.fromJson(change.newRecord));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel case final channel?) await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  @override
  Future<Profile> me() => _guard(() async {
        if (_client.auth.currentUser == null) throw const OnlineException(OnlineFailure.notSignedIn);
        // Livello, esperienza e monete non sono colonne pubbliche: il proprio
        // profilo intero arriva solo da questa funzione.
        final rows = await _client.rpc<List<dynamic>>('my_profile');
        if (rows.isEmpty) throw const OnlineException(OnlineFailure.notSignedIn, null, 'my_profile returned no row');
        return Profile.fromJson(rows.first as Map<String, dynamic>);
      });

  @override
  Future<Profile> update({required String handle, LobbyLanguage? language}) => _guard(() async {
        await _client.from('profiles').update({
          'handle': Profile.normalizeHandle(handle),
          if (language != null) 'language': language.name,
        }).eq('id', _me);
        return me();
      });

  @override
  Future<Profile> saveFace(Map<String, String> face, {required String tone, String? mark}) => _guard(() async {
        final rows = await _client.rpc<List<dynamic>>('save_face', params: {'p_face': face, 'p_tone': tone, 'p_mark': mark});
        if (rows.isEmpty) throw const OnlineException(OnlineFailure.notSignedIn);
        return Profile.fromJson(rows.first as Map<String, dynamic>);
      });

  @override
  Future<Profile> setPicture(ProfilePicture picture) => _guard(() async {
        await _client.from('profiles').update({'picture': picture.name}).eq('id', _me);
        return me();
      });

  @override
  Future<bool> refreshSteam() async {
    if (_client.auth.currentUser == null) return false;
    try {
      final response = await _client.functions.invoke('steam-auth', body: {'action': 'refresh'});
      return (response.data as Map?)?['refreshed'] == true;
    } catch (error) {
      debugPrint('steam-auth refresh · $error');
      return false;
    }
  }

  @override
  Future<bool> handleAvailable(String handle) => _guard(() async {
        final rows = await _client
            .from('profiles')
            .select('id')
            .eq('handle', Profile.normalizeHandle(handle))
            .neq('id', _me)
            .limit(1);
        return rows.isEmpty;
      });

  @override
  Future<List<Profile>> search(String handlePrefix) => _guard(() async {
        final prefix = handlePrefix.toLowerCase().replaceAll(RegExp('[^a-z0-9._]'), '');
        if (prefix.isEmpty) return const <Profile>[];
        final rows = await _client
            .from('profiles')
            .select(_profileColumns)
            .like('handle', '${prefix.replaceAll('_', r'\_')}%')
            .neq('id', _me)
            .order('handle')
            .limit(20);
        return [for (final row in rows) Profile.fromJson(row)];
      });

  @override
  Future<PublicProfile> publicProfile(String handleOrId) => _guard(() async => PublicProfile.fromJson(
      (await _client.rpc<Map<String, dynamic>>('public_stats', params: {'target': handleOrId})).cast<String, Object?>()));

  @override
  Future<Profile> setPublicProfile(bool visible) => _guard(() async {
        await _client.from('profiles').update({'public_profile': visible}).eq('id', _me);
        return me();
      });

  @override
  Future<Profile> setTableReactions(bool on) => _guard(() async {
        await _client.from('profiles').update({'table_reactions': on}).eq('id', _me);
        return me();
      });
}

class SupabaseFriends implements FriendsRepository {
  final SupabaseClient _client;

  SupabaseFriends(this._client);

  @override
  Future<List<Friendship>> list() => _guard(() async {
        final me = _client.auth.currentUser?.id;
        if (me == null) throw const OnlineException(OnlineFailure.notSignedIn);
        final rows = await _client.from('friendships').select(
              'requester, addressee, status, '
              'requester_profile:profiles!friendships_requester_fkey($_profileColumns), '
              'addressee_profile:profiles!friendships_addressee_fkey($_profileColumns)',
            );
        return [
          for (final row in rows)
            if (row['status'] != 'blocked')
              Friendship(
                other: Profile.fromJson(
                  (row['requester'] == me ? row['addressee_profile'] : row['requester_profile']) as Map<String, dynamic>,
                ),
                status: FriendStatus.values.byName(row['status'] as String),
                incoming: row['addressee'] == me,
              ),
        ];
      });

  @override
  Future<FriendStatus> request(String profileId) => _guard(() async {
        final status = await _client.rpc<String>('send_friend_request', params: {'target': profileId});
        return FriendStatus.values.byName(status);
      });

  @override
  Future<void> respond(String requesterId, {required bool accept}) => _guard(
        () => _client.rpc<String>('respond_friend_request', params: {'requester_id': requesterId, 'accept': accept}),
      );

  @override
  Future<void> remove(String profileId) =>
      _guard(() => _client.rpc<void>('remove_friend', params: {'other': profileId}));
}

/// Segnalare e bloccare: `report_player`, `block_player`, `unblock_player`;
/// i propri blocchi si leggono da `player_blocks` (la policy mostra solo i
/// propri).
class SupabaseSafety implements SafetyRepository {
  final SupabaseClient _client;

  SupabaseSafety(this._client);

  @override
  Future<void> report(String targetId, ReportReason reason, {String? note, String? gameId, String? messageId}) =>
      _guard(
        () => _client.rpc<void>(
          'report_player',
          params: {
            'target': targetId,
            'reason': reason.name,
            'note': note,
            'game_id': gameId,
            'message_id': messageId,
          },
        ),
      );

  @override
  Future<List<Profile>> blocked() => _guard(() async {
        final rows = await _client
            .from('player_blocks')
            .select('blocked, profile:profiles!player_blocks_blocked_fkey($_profileColumns)')
            .order('created_at', ascending: false);
        final profiles = [
          for (final row in rows)
            if (row['profile'] case final Map<String, dynamic> profile) Profile.fromJson(profile),
        ];
        BlockedPlayers.set([for (final row in rows) row['blocked'] as String]);
        return profiles;
      });

  @override
  Future<void> block(String profileId) => _guard(() async {
        await _client.rpc<void>('block_player', params: {'other': profileId});
        BlockedPlayers.add(profileId);
      });

  @override
  Future<void> unblock(String profileId) => _guard(() async {
        await _client.rpc<void>('unblock_player', params: {'other': profileId});
        BlockedPlayers.remove(profileId);
      });
}

class SupabaseRooms implements RoomRepository {
  final SupabaseClient _client;

  SupabaseRooms(this._client);

  @override
  Future<Room> create(LobbyLanguage language) => _guard(() async {
        final row = await _client.rpc<Map<String, dynamic>>('create_room', params: {'room_language': language.name});
        return Room.fromJson(row);
      });

  @override
  Future<Room> join(String code) => _guard(() async {
        final row = await _client.rpc<Map<String, dynamic>>('join_room', params: {'join_code': code});
        return Room.fromJson(row);
      });

  @override
  Future<void> leave(String roomId, {String? newHostId, bool autoHeir = false}) => _guard(
        () => _client.rpc<void>('leave_room', params: {'room': roomId, 'new_host': newHostId, 'auto_heir': autoHeir}),
      );

  @override
  Future<Room?> fetch(String roomId) => _guard(() async {
        final row = await _client.from('rooms').select().eq('id', roomId).maybeSingle();
        return row == null ? null : Room.fromJson(row);
      });

  Future<List<RoomMember>> _members(String roomId) async {
    final rows = await _client
        .from('room_members')
        .select('seat, profile:profiles($_profileColumns)')
        .eq('room_id', roomId)
        .isFilter('left_at', null)
        .order('seat');
    return [
      for (final row in rows)
        RoomMember(
          profile: Profile.fromJson(row['profile'] as Map<String, dynamic>),
          seat: (row['seat'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<Room?> current() => _guard(() async {
        // La policy lascia vedere solo le stanze in cui si siede.
        final row = await _client.from('rooms').select().order('created_at', ascending: false).limit(1).maybeSingle();
        return row == null ? null : Room.fromJson(row);
      });

  @override
  Stream<List<RoomMember>> watchMembers(String roomId) {
    late final StreamController<List<RoomMember>> controller;
    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        final members = await _members(roomId);
        if (!controller.isClosed) controller.add(members);
      } catch (error) {
        if (!controller.isClosed) controller.addError(_translate(error));
      }
    }

    controller = StreamController<List<RoomMember>>(
      onListen: () {
        // Ogni cambio nella stanza si rilegge per intero: sono al massimo
        // sedici righe, e così nome e faccia arrivano insieme.
        channel = _client
            .channel('room-members:$roomId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'room_members',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
              callback: (_) => refresh(),
            )
            // La stanza stessa: i bot, la partita che comincia.
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'rooms',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: roomId),
              callback: (_) => refresh(),
            )
            .subscribe((status, _) {
              if (status == RealtimeSubscribeStatus.subscribed) refresh();
            });
        refresh();
      },
      onCancel: () async {
        if (channel case final channel?) await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }
}

/// La partita online su Supabase: tre tabelle lette con le policy (il
/// tavolo, la propria vista, la chat) e le funzioni che scrivono. La
/// partita la manda avanti il server (la Edge Function `game`). Ogni
/// cambio arriva con Realtime e si rilegge per intero:
/// così l'ordine degli eventi non conta, e chi si ricollega riparte dalla
/// versione attuale.
class SupabaseGame implements GameBackend {
  final SupabaseClient _client;

  SupabaseGame(this._client);

  @override
  Future<void> startGame(String roomId) => _guard(() => _client.rpc<void>('start_game', params: {'room': roomId}));

  /// Un canale Realtime su [tables] della stanza: a ogni cambio (e a ogni
  /// ricollegamento) si chiama [refresh].
  Stream<T> _watch<T>(String name, List<String> tables, String roomId, Future<T?> Function() read, {Duration? poll}) {
    late final StreamController<T> controller;
    RealtimeChannel? channel;
    Timer? timer;

    Future<void> refresh() async {
      try {
        final value = await read();
        if (value != null && !controller.isClosed) controller.add(value);
      } catch (error) {
        if (!controller.isClosed) controller.addError(_translate(error));
      }
    }

    controller = StreamController<T>(
      onListen: () {
        // Un nome nuovo per ogni abbonamento: chi rientra apre il suo canale
        // prima che il vecchio sia chiuso, e chiudere il vecchio non deve
        // chiudere anche il nuovo (stesso nome, stesso canale sul server).
        var builder = _client.channel('$name:$roomId:${++_channels}');
        for (final table in tables) {
          builder = builder.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'room_id', value: roomId),
            callback: (_) => refresh(),
          );
        }
        channel = builder.subscribe((status, _) {
          // Riabbonato (anche dopo un errore, da solo) o caduto: si rilegge
          // comunque, così chi ha perso un cambio lo recupera.
          if (status != RealtimeSubscribeStatus.closed) refresh();
        });
        refresh();
        // Riserva: se Realtime non consegna i cambi, si rilegge lo stesso.
        if (poll != null) timer = Timer.periodic(poll, (_) => refresh());
      },
      onCancel: () async {
        timer?.cancel();
        if (channel case final channel?) await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  int _channels = 0;

  @override
  Future<void> resume() => _guard(() async {
        final auth = _client.auth;
        final session = auth.currentSession;
        if (session == null) throw const OnlineException(OnlineFailure.notSignedIn);
        // Dopo lo sfondo il token può essere scaduto: senza, le chiamate e
        // il tempo reale non passano (o passano come anonimi).
        if (session.isExpired ||
            (session.expiresAt != null &&
                DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
                    .isBefore(DateTime.now().add(const Duration(minutes: 1))))) {
          await auth.refreshSession();
        }
        // I canali nuovi (il riabbonamento che segue) riaprono il socket
        // se è caduto; il token va dato anche a quelli già aperti.
        final token = auth.currentSession?.accessToken;
        if (token != null) await _client.realtime.setAuth(token);
      });

  @override
  Stream<GameFeed> watchGame(String roomId) =>
      _watch('game-feed', ['game_public', 'game_seat_views'], roomId, () async {
        final board = await _client.from('game_public').select('version, view').eq('room_id', roomId).maybeSingle();
        // La policy lascia leggere solo la propria riga.
        final seat = await _client
            .from('game_seat_views')
            .select('seat, version, view')
            .eq('room_id', roomId)
            .maybeSingle();
        final view = board?['view'] as Map?;
        return GameFeed(
          board: board == null || view == null
              ? null
              : PublicFrame((board['version'] as num).toInt(), view.cast<String, Object?>()),
          seat: seat == null
              ? null
              : SeatFrame(
                  seat['seat'] as String,
                  (seat['version'] as num).toInt(),
                  (seat['view'] as Map).cast<String, Object?>(),
                ),
        );
      });

  @override
  Future<String> sendIntent(String roomId, PlayerIntent intent) =>
      _guard(() => _client.rpc<String>('submit_intent', params: {'room': roomId, 'intent': intent.toJson()}));

  @override
  Future<void> sendAck(String roomId, String seat, String stage) => _guard(() => _client.rpc<String>(
        'submit_intent',
        params: {
          'room': roomId,
          'intent': {'type': 'ack', 'seat': seat, 'stage': stage},
        },
      ));

  @override
  Future<void> leaveGame(String roomId) => _guard(() => _client.rpc<void>('game_leave', params: {'room': roomId}));

  @override
  Future<int> ping(String roomId) => _guard(() async {
        final now = await _client.rpc<num>('game_ping', params: {'room': roomId});
        return now.toInt();
      });

  @override
  Future<String> sendChat(String roomId, ChatChannel channel, String body) =>
      _guard(() => _client.rpc<String>('send_chat', params: {'room': roomId, 'channel': channel.name, 'body': body}));

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) =>
      _watch('game-chat', ['game_chat', 'game_events'], roomId, () async {
        // Le policy lasciano leggere solo i canali di questo telefono, e
        // degli eventi quelli pubblici e i propri della partita in corso.
        final rows = await _client
            .from('game_chat')
            .select('id, n, channel, profile_id, seat, name, body, created_at')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .order('n', ascending: false)
            .limit(100);
        final events = await _client
            .from('game_events')
            .select('recipient, n, kind, data, created_at')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(100);
        return [
          for (final row in rows) ChatMessage.fromJson(row),
          for (final row in events)
            ChatMessage.event(
              kind: row['kind'] as String,
              data: (row['data'] as Map).cast<String, Object?>(),
              private: row['recipient'] != null,
              n: (row['n'] as num).toInt(),
              at: DateTime.parse(row['created_at'] as String),
            ),
        ]..sort(ChatMessage.byTime);
      }, poll: const Duration(seconds: 5));
}

/// I gesti del tavolo: si lanciano con `send_reaction`, arrivano da
/// `table_reactions` in tempo reale (la policy toglie quelli dei bloccati).
class SupabaseReactions implements ReactionsRepository {
  final SupabaseClient _client;
  final SupabaseGame _game;

  SupabaseReactions(this._client, this._game);

  @override
  Future<int?> send(String roomId, String toSeat, TableGesture gesture) => _guard(() async {
        final id = await _client.rpc<int>('send_reaction',
            params: {'room': roomId, 'target_seat': toSeat, 'reaction_id': gesture.name});
        return id == 0 ? null : id;
      });

  @override
  Stream<List<TableReaction>> watch(String roomId) => _game._watch('table-reactions', ['table_reactions'], roomId, () async {
        final rows = await _client
            .from('table_reactions')
            .select('id, profile_id, from_seat, to_seat, reaction, created_at')
            .eq('room_id', roomId)
            .order('id', ascending: false)
            .limit(20);
        return [for (final row in rows.reversed) ?TableReaction.fromJson(row)];
      }, poll: const Duration(seconds: 6));

  @override
  Future<Set<TableGesture>> owned() => _guard(() async {
        final rows = await _client.from('shop_inventory').select('item_id').like('item_id', 'gesture.%');
        return {for (final row in rows) ?TableGesture.byId((row['item_id'] as String).substring(8))};
      });
}

/// La bottega sul server: il catalogo e la vetrina si leggono, comprare e
/// indossare passano dalle funzioni `buy_item`, `equip_item` e `unequip_slot`.
class SupabaseShop implements ShopRepository {
  final SupabaseClient _client;

  SupabaseShop(this._client);

  @override
  Future<List<ShopItem>> catalog() => _guard(() async {
        final rows = await _client.from('shop_items').select().order('sort');
        return [for (final row in rows) ShopItem.fromJson(row)];
      });

  @override
  Future<List<ShopFeature>> featured() => _guard(() async {
        // La policy lascia vedere solo le finestre aperte adesso.
        final rows = await _client.from('shop_rotations').select('item_id, starts_at, ends_at, sort').order('sort');
        return [for (final row in rows) ShopFeature.fromJson(row)];
      });

  @override
  Future<Set<String>> owned() => _guard(() async {
        final rows = await _client.from('shop_inventory').select('item_id');
        return {for (final row in rows) row['item_id'] as String};
      });

  Future<Profile> _profileFrom(Future<List<dynamic>> call) async {
    final rows = await call;
    if (rows.isEmpty) throw const OnlineException(OnlineFailure.notSignedIn);
    return Profile.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<Profile> buy(String itemId) =>
      _guard(() => _profileFrom(_client.rpc<List<dynamic>>('buy_item', params: {'p_item': itemId})));

  @override
  Future<List<ShopBundle>> bundles() => _guard(() async {
        final rows = await _client.from('shop_bundles').select('*, shop_bundle_items(item_id)').order('sort');
        return [for (final row in rows) ShopBundle.fromJson(row)];
      });

  @override
  Future<Profile> buyBundle(String bundleId) =>
      _guard(() => _profileFrom(_client.rpc<List<dynamic>>('buy_bundle', params: {'p_bundle': bundleId})));

  @override
  Future<Profile> equip(String itemId, {String? tone, Map<String, String>? current, String? hand}) => _guard(() => _profileFrom(
      _client.rpc<List<dynamic>>('equip_item', params: {'p_item': itemId, 'p_tone': tone, 'p_current': current, 'p_hand': ?hand})));

  @override
  Future<Profile> unequip(String slot, {String? tone, Map<String, String>? current}) => _guard(() => _profileFrom(
      _client.rpc<List<dynamic>>('unequip_slot', params: {'p_slot': slot, 'p_tone': tone, 'p_current': current})));
}

/// L'esportazione passa da `export_my_data()`; l'eliminazione dalla Edge
/// Function `account`, che ha il ruolo di servizio per togliere l'utente.
class SupabaseAccount implements AccountRepository {
  final SupabaseClient _client;

  SupabaseAccount(this._client);

  @override
  Future<Map<String, dynamic>> exportData() => _guard(() async {
        if (_client.auth.currentUser == null) throw const OnlineException(OnlineFailure.notSignedIn);
        final data = await _client.rpc<dynamic>('export_my_data');
        return Map<String, dynamic>.from(data as Map);
      });

  @override
  Future<void> deleteAccount() => _guard(() async {
        final user = _client.auth.currentUser;
        if (user == null) throw const OnlineException(OnlineFailure.notSignedIn);
        // Apple chiede di revocare il suo token: serve un codice fresco, che
        // solo un nuovo foglio di Apple dà. Se chi gioca lo chiude, l'account
        // si elimina lo stesso.
        String? appleCode;
        final providers = (user.appMetadata['providers'] as List?) ?? [user.appMetadata['provider']];
        if (providers.contains('apple') && !kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          try {
            final credential = await SignInWithApple.getAppleIDCredential(scopes: const []);
            appleCode = credential.authorizationCode;
          } catch (_) {}
        }
        final response = await _client.functions.invoke('account', body: {
          'action': 'delete',
          'apple_authorization_code': ?appleCode,
        });
        if (response.status != 200) {
          throw OnlineException(OnlineFailure.unknown, null, 'account · ${response.status} · ${response.data}');
        }
        try {
          await _client.auth.signOut();
        } catch (_) {}
      });
}

/// «Collega account» senza codici (migrazione
/// 20261107100000_link_identities.sql, Edge Function `steam-auth`):
///   * sul desktop, Apple o Google: il login OAuth nel browser di sistema
///     (PKCE, ritorno su 127.0.0.1) su un client auth usa e getta; il token
///     di quella sessione va al server, che unisce i due profili;
///   * sul telefono, Steam: OpenID nel browser, ritorno su
///     `oberta://steam-link` con un codice monouso legato allo `state`.
/// Se resta l'altro profilo (il più vecchio), il server dà un token
/// magic link e l'app entra lì.
class SupabaseAccountLinks implements AccountLinkRepository {
  final SupabaseClient _client;
  final OnlineConfig _config;

  SupabaseAccountLinks(this._client, this._config);

  String get _base => _config.supabaseUrl.replaceAll(RegExp(r'/$'), '');

  @override
  List<LinkProvider> get providers {
    if (kIsWeb) return const [];
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return const [LinkProvider.apple, LinkProvider.google];
    return const [LinkProvider.steam];
  }

  @override
  Future<bool> link(LinkProvider provider) => _guard(() async {
        final body = switch (provider) {
          LinkProvider.steam => await _steamProof(),
          LinkProvider.apple => await _oauthProof(OAuthProvider.apple),
          LinkProvider.google => await _oauthProof(OAuthProvider.google),
        };
        final FunctionResponse response;
        try {
          response = await _client.functions.invoke('steam-auth', body: body);
        } on FunctionException catch (error) {
          final code = (error.details as Map?)?['error'];
          throw OnlineException(
            switch (code) {
              'link_same_account' => OnlineFailure.linkSameAccount,
              'link_conflict' => OnlineFailure.linkConflict,
              'already_in_game' => OnlineFailure.alreadyInGame,
              'not_signed_in' => OnlineFailure.notSignedIn,
              _ => OnlineFailure.unknown,
            },
            error,
            'steam-auth · link · ${error.status} · ${error.details}',
          );
        }
        final data = (response.data as Map?) ?? const {};
        if (data['switched'] != true) return false;
        final tokenHash = data['token_hash'] as String?;
        if (tokenHash == null) throw OnlineException(OnlineFailure.unknown, null, 'steam-auth · link · $data');
        await _client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
        return true;
      });

  /// «Collega Steam» sul telefono: Steam nel browser, ritorno sull'app.
  Future<Map<String, String>> _steamProof() async {
    final state = BrowserLoopback.newState();
    final back = IncomingLinks.instance.steamLinks
        .firstWhere((uri) => uri.queryParameters['state'] == state)
        .timeout(BrowserLoopback.timeout, onTimeout: () => throw const OnlineException(OnlineFailure.cancelled));
    final start = Uri.parse('$_base/functions/v1/steam-auth')
        .replace(queryParameters: {'action': 'start', 'mode': 'link', 'state': state});
    if (!await launchUrl(start, mode: LaunchMode.externalApplication)) {
      throw const OnlineException(OnlineFailure.unknown, null, 'browser did not open');
    }
    final uri = await back;
    final code = uri.queryParameters['ticket'];
    if (code == null) throw const OnlineException(OnlineFailure.cancelled);
    return {'action': 'link_steam', 'code': code, 'state': state};
  }

  /// «Collega Apple / Google» sul desktop: il login nel browser, su un
  /// client auth a parte (la sessione Steam resta dov'è).
  Future<Map<String, String>> _oauthProof(OAuthProvider provider) async {
    final other = GoTrueClient(
      url: '$_base/auth/v1',
      headers: {'apikey': _config.supabaseAnonKey, 'Authorization': 'Bearer ${_config.supabaseAnonKey}'},
      autoRefreshToken: false,
      asyncStorage: _MemoryStorage(),
      flowType: AuthFlowType.pkce,
    );
    try {
      final query = await BrowserLoopback.wait(
        start: (port) async => Uri.parse(
          (await other.getOAuthSignInUrl(provider: provider, redirectTo: 'http://127.0.0.1:$port/link')).url,
        ),
        path: '/link',
        accept: (query) => query['code'] != null || query['error'] != null,
      );
      final code = query['code'];
      if (code == null) {
        throw OnlineException(OnlineFailure.cancelled, null, '${provider.name} · ${query['error_description'] ?? query['error']}');
      }
      final session = (await other.exchangeCodeForSession(code)).session;
      return {'action': 'link_identity', 'other_token': session.accessToken};
    } finally {
      other.dispose();
    }
  }
}

/// Dove il client usa e getta tiene il verificatore PKCE: solo in memoria.
class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async => _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

/// La classificata su Supabase: la coda (funzioni del database), il rating
/// e la cronologia (righe proprie, lette con le policy).
class SupabaseRanked implements RankedRepository {
  final SupabaseClient _client;

  SupabaseRanked(this._client);

  @override
  Future<RankedStatus> status() => _guard(() async =>
      RankedStatus.fromJson((await _client.rpc<Map<String, dynamic>>('ranked_status')).cast<String, Object?>()));

  @override
  Future<RankedStatus> enqueue(LobbyLanguage language) => _guard(() async {
    // Se un tavolo si riempie o si blocca proprio mentre ci si siede, il
    // server annulla l'ingresso: si riprova, e il server sceglie un altro
    // tavolo (quelli occupati li salta).
    for (var attempt = 0;; attempt++) {
      try {
        return RankedStatus.fromJson(
          (await _client.rpc<Map<String, dynamic>>('enqueue_ranked', params: {'queue_language': language.name}))
              .cast<String, Object?>(),
        );
      } on PostgrestException catch (error) {
        final busy = const {'40P01', '40001', '55P03'}.contains(error.code) || error.message.contains('room_full');
        if (!busy || attempt >= 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 150 + 250 * attempt + Random().nextInt(200)));
      }
    }
  });

  @override
  Future<void> leave() => _guard(() => _client.rpc<void>('leave_ranked_queue'));

  @override
  Future<Set<String>> completeTutorial(String faction) => _guard(() async {
        final done = await _client.rpc<List<dynamic>>('tutorial_complete', params: {'faction': faction});
        return {...done.whereType<String>()};
      });

  @override
  Future<Set<String>> skipTutorials() => _guard(() async {
        final done = await _client.rpc<List<dynamic>>('tutorial_skip');
        return {...done.whereType<String>()};
      });

  @override
  Future<OnlineCounts> counts() => _guard(() async =>
      OnlineCounts.fromJson((await _client.rpc<Map<String, dynamic>>('online_counts')).cast<String, Object?>()));

  @override
  Future<Map<LobbyLanguage, Rating>> ratings() => _guard(() async {
        final rows = await _client.from('ratings').select('language, mu, sigma');
        return {
          for (final row in rows)
            (LobbyLanguage.parse(row['language'])):
                Rating((row['mu'] as num).toDouble(), (row['sigma'] as num).toDouble()),
        };
      });

  @override
  Future<MatchResult?> lastResult({DateTime? since}) => _guard(() async {
        var query = _client.from('match_history').select();
        if (since != null) query = query.gte('played_at', since.toUtc().toIso8601String());
        final row = await query.order('played_at', ascending: false).limit(1).maybeSingle();
        return row == null ? null : MatchResult.fromJson(row.cast<String, Object?>());
      });

  @override
  Future<List<MatchResult>> history({int limit = 5}) => _guard(() async {
        final rows = await _client.from('match_history').select().order('played_at', ascending: false).limit(limit);
        return [for (final row in rows) MatchResult.fromJson(row.cast<String, Object?>())];
      });

  @override
  Future<PlayerStats> stats() => _guard(() async =>
      PlayerStats.fromJson((await _client.rpc<Map<String, dynamic>>('my_stats')).cast<String, Object?>()));
}

class SupabaseDeviceSessions implements DeviceSessionRepository {
  final SupabaseClient _client;

  SupabaseDeviceSessions(this._client);

  SessionAnswer _answer(Object? json) => SessionAnswer.fromJson((json as Map).cast<String, Object?>());

  @override
  Future<SessionAnswer> claim(String sessionId, String deviceLabel, {bool force = false}) => _guard(() async =>
      _answer(await _client.rpc<dynamic>('claim_session',
          params: {'session_id': sessionId, 'device_label': deviceLabel, 'force': force})));

  @override
  Future<SessionAnswer> status(String sessionId) =>
      _guard(() async => _answer(await _client.rpc<dynamic>('session_status', params: {'session_id': sessionId})));

  @override
  Stream<void> changes() {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const Stream.empty();
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('session:$me')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'session_signals',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'profile_id', value: me),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel case final channel?) await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }
}

/// Missions, achievements and the leaderboard: all read through server
/// functions, never written by the phone.
class SupabaseProgress implements ProgressRepository {
  final SupabaseClient _client;

  SupabaseProgress(this._client);

  @override
  Future<PlayerProgress> mine() => _guard(() async =>
      PlayerProgress.fromJson((await _client.rpc<Map<String, dynamic>>('my_progress')).cast<String, Object?>()));

  @override
  Future<Map<String, RoleRecord>> roleStats() =>
      _guard(() async => RoleRecord.listFromJson(await _client.rpc<dynamic>('my_role_stats')));

  @override
  Future<MissionClaim> claim(String missionId) => _guard(() async => MissionClaim.fromJson(
      (await _client.rpc<Map<String, dynamic>>('claim_mission', params: {'p_mission': missionId})).cast<String, Object?>()));

  @override
  Future<GameUnlocks> unlocksFor(String gameId) => _guard(() async => GameUnlocks.fromJson(
      (await _client.rpc<Map<String, dynamic>>('game_unlocks', params: {'game': gameId})).cast<String, Object?>()));

  @override
  Future<Leaderboard> leaderboard(LobbyLanguage language) => _guard(() async => Leaderboard.fromJson(
      (await _client.rpc<Map<String, dynamic>>('leaderboard', params: {'board_language': language.name}))
          .cast<String, Object?>()));
}

/// La build minima e il negozio di questa piattaforma.
class SupabaseAppRequirements implements AppRequirementsRepository {
  final SupabaseClient _client;

  SupabaseAppRequirements(this._client);

  @override
  Future<AppRequirements> requirements(String platform) => _guard(() async {
        final json = await _client.rpc<dynamic>('app_requirements', params: {'platform': platform});
        return AppRequirements.fromJson((json as Map).cast<String, Object?>());
      });
}
