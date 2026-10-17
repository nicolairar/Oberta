import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
import '../rules/intent.dart';
import 'online_config.dart';
import 'online_services.dart';

/// L'online vero, su Supabase. Lo apre `main` quando l'app è stata compilata
/// con la configurazione; i test usano invece `FakeOnline`.
Future<OnlineServices?> openSupabaseOnline(OnlineConfig config) async {
  if (!config.isComplete) return null;
  try {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
  } catch (error) {
    debugPrint('Supabase non disponibile: $error');
    return null;
  }
  final client = Supabase.instance.client;
  return OnlineServices(
    auth: SupabaseAuth(client, config),
    profiles: SupabaseProfiles(client),
    friends: SupabaseFriends(client),
    rooms: SupabaseRooms(client),
    game: SupabaseGame(client),
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
  if (error is AuthWeakPasswordException || code == 'weak_password') return OnlineFailure.weakPassword;
  if (code == 'invalid_credentials' || message.contains('invalid login credentials')) {
    return OnlineFailure.wrongPassword;
  }
  if (code == 'user_already_exists' || code == 'email_exists') return OnlineFailure.wrongPassword;
  if (code == 'email_address_invalid' || message.contains('unable to validate email')) {
    return OnlineFailure.invalidEmail;
  }
  if (code == 'email_not_confirmed') return OnlineFailure.emailNotConfirmed;
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
      'not_allowed' => OnlineFailure.notAllowed,
      'request_not_found' => OnlineFailure.requestNotFound,
      'invalid_seats' || 'not_your_seat' || 'stale_version' || 'too_many_intents' => OnlineFailure.notAllowed,
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
const _profileColumns = 'id, handle, language, avatar';

/// Un valore casuale da usare una volta sola: Supabase controlla che il
/// token di Apple o Google porti la sua impronta, così un token rubato non
/// si può riusare altrove.
String _rawNonce() {
  final random = Random.secure();
  return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
}

String _sha256(String text) => sha256.convert(utf8.encode(text)).toString();

class SupabaseAuth extends OnlineAuth {
  final SupabaseClient _client;
  final OnlineConfig _config;
  late final StreamSubscription<AuthState> _changes;
  String? _suggestedName;

  /// Google vuole essere preparato una volta sola per tutta la vita
  /// dell'app, e il nonce si passa lì: quello resta per la sessione.
  String? _googleNonce;

  SupabaseAuth(this._client, this._config) {
    _changes = _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  bool get appleAvailable => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  bool get googleAvailable => _config.hasGoogle && !kIsWeb && Platform.isIOS;

  @override
  String? get suggestedName => _suggestedName;

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
          await google.initialize(
            clientId: _config.googleIosClientId,
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

  @override
  Future<void> signInWithTestAccount({required String email, required String password}) => _guard(() async {
        final address = email.trim();
        try {
          await _client.auth.signInWithPassword(email: address, password: password);
          return;
        } on AuthException catch (error) {
          // Credenziali sbagliate vuol dire anche «account che non c'è»:
          // si prova a crearlo, e se c'era già era la password.
          if (_authFailure(error, SignInDoor.email) != OnlineFailure.wrongPassword) rethrow;
        }
        final created = await _client.auth.signUp(email: address, password: password);
        if (created.session == null) {
          throw const OnlineException(
            OnlineFailure.emailNotConfirmed,
            null,
            'signUp returned no session: turn off "Confirm email" in Supabase',
          );
        }
      }, SignInDoor.email);

  @override
  Future<void> signOut() => _guard(() async {
        await _client.auth.signOut();
        if (_googleNonce != null) await GoogleSignIn.instance.signOut();
      });

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
  Future<Profile> me() => _guard(() async {
        if (_client.auth.currentUser == null) throw const OnlineException(OnlineFailure.notSignedIn);
        // Livello, esperienza e monete non sono colonne pubbliche: il proprio
        // profilo intero arriva solo da questa funzione.
        final rows = await _client.rpc<List<dynamic>>('my_profile');
        if (rows.isEmpty) throw const OnlineException(OnlineFailure.notSignedIn, null, 'my_profile returned no row');
        return Profile.fromJson(rows.first as Map<String, dynamic>);
      });

  @override
  Future<Profile> update({required String handle, AppLanguage? language}) => _guard(() async {
        await _client.from('profiles').update({
          'handle': Profile.normalizeHandle(handle),
          if (language != null) 'language': language.name,
        }).eq('id', _me);
        return me();
      });

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

class SupabaseRooms implements RoomRepository {
  final SupabaseClient _client;

  SupabaseRooms(this._client);

  @override
  Future<Room> create(AppLanguage language) => _guard(() async {
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
/// tavolo, la propria vista, le intenzioni per l'host) e le funzioni che
/// scrivono. Ogni cambio arriva con Realtime e si rilegge per intero:
/// così l'ordine degli eventi non conta, e chi si ricollega riparte dalla
/// versione attuale.
class SupabaseGame implements GameBackend {
  final SupabaseClient _client;

  SupabaseGame(this._client);

  @override
  Future<void> setBots(String roomId, int count) =>
      _guard(() => _client.rpc<void>('set_room_bots', params: {'room': roomId, 'count': count}));

  @override
  Future<void> startGame(String roomId, List<SeatPlan> seats) => _guard(
        () => _client.rpc<void>('start_game', params: {
          'room': roomId,
          'seats': [for (final seat in seats) seat.toJson()],
        }),
      );

  @override
  Future<void> publish(String roomId, GamePublication publication) => _guard(
        () => _client.rpc<void>('publish_game', params: {
          'room': roomId,
          'new_version': publication.version,
          'public_view': publication.board,
          'seat_views': publication.seatViews,
          'host_state': publication.hostState,
          'last_intent': publication.lastIntent,
          'finished': publication.finished,
        }),
      );

  @override
  Future<Map<String, Object?>?> loadHostState(String roomId) => _guard(() async {
        final row = await _client.from('game_host_state').select('state').eq('room_id', roomId).maybeSingle();
        return (row?['state'] as Map?)?.cast<String, Object?>();
      });

  /// Un canale Realtime su [tables] della stanza: a ogni cambio (e a ogni
  /// ricollegamento) si chiama [refresh].
  Stream<T> _watch<T>(String name, List<String> tables, String roomId, Future<T?> Function() read) {
    late final StreamController<T> controller;
    RealtimeChannel? channel;

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
        var builder = _client.channel('$name:$roomId');
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

  @override
  Stream<List<IntentEnvelope>> watchIntents(String roomId) => _watch('game-intents', ['game_intents'], roomId, () async {
        final rows = await _client.from('game_intents').select('id, seat, intent').eq('room_id', roomId).order('id');
        return [
          for (final row in rows)
            IntentEnvelope(
              id: (row['id'] as num).toInt(),
              seat: row['seat'] as String,
              intent: (row['intent'] as Map).cast<String, Object?>(),
            ),
        ];
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
  Future<int> sendIntent(String roomId, PlayerIntent intent) => _guard(() async {
        final id = await _client.rpc<num>('submit_intent', params: {'room': roomId, 'intent': intent.toJson()});
        return id.toInt();
      });
}
