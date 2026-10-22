import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'steam.dart';

/// Steamworks via FFI sull'API "flat" in C di `steam_api` (SDK 1.57 o più
/// nuovo: serve `GetAuthTicketForWebApi`). Solo le poche funzioni che ci
/// servono, cercate per nome con le versioni d'interfaccia di ripiego.
///
/// La libreria NON è nel repository (la licenza dell'SDK non permette di
/// metterla in un repo pubblico): si scarica dall'SDK e si copia accanto
/// all'eseguibile, vedi docs/steam.md.
class FfiSteam extends SteamClient {
  final DynamicLibrary _lib;
  final int _pipe;
  final Pointer<Void> _user;
  final Pointer<Void> _friends;
  final Pointer<Void> _stats;
  Timer? _pump;
  final _waiting = <int, Completer<Uint8List?>>{};

  FfiSteam._(this._lib, this._pipe, this._user, this._friends, this._stats);

  /// L'ultimo motivo per cui non si è agganciato (per il menu di prova).
  static String? lastProblem;

  /// Carica la libreria e si aggancia a Steam; null se non si può.
  static FfiSteam? tryOpen({required int appId}) {
    final lib = _openLibrary();
    if (lib == null) {
      lastProblem = 'steam_api library not found next to the executable';
      return null;
    }
    try {
      _setAppIdIfMissing(appId);
      if (!_isSteamRunning(lib)) {
        lastProblem = 'Steam is not running';
        return null;
      }
      final problem = _init(lib);
      if (problem != null) {
        lastProblem = problem;
        return null;
      }
      lib.lookupFunction<Void Function(), void Function()>('SteamAPI_ManualDispatch_Init')();
      final pipe = lib.lookupFunction<Int32 Function(), int Function()>('SteamAPI_GetHSteamPipe')();
      final steam = FfiSteam._(
        lib,
        pipe,
        _accessor(lib, 'SteamAPI_SteamUser', const ['v023', 'v022', 'v021']),
        _accessor(lib, 'SteamAPI_SteamFriends', const ['v018', 'v017']),
        _accessor(lib, 'SteamAPI_SteamUserStats', const ['v013', 'v012']),
      );
      steam._pump = Timer.periodic(const Duration(milliseconds: 100), (_) => steam._runFrame());
      lastProblem = null;
      return steam;
    } catch (error) {
      lastProblem = 'steam init failed: $error';
      debugPrint('steam · $lastProblem');
      return null;
    }
  }

  static String get _libraryName {
    if (Platform.isWindows) return 'steam_api64.dll';
    if (Platform.isMacOS) return 'libsteam_api.dylib';
    return 'libsteam_api.so';
  }

  static DynamicLibrary? _openLibrary() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = [
      '$exeDir$sep$_libraryName',
      if (Platform.isMacOS) '$exeDir$sep..${sep}Frameworks$sep$_libraryName',
      if (Platform.isLinux) '$exeDir${sep}lib$sep$_libraryName',
      _libraryName,
    ];
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (_) {}
    }
    return null;
  }

  /// In sviluppo Steam deve sapere l'App ID: o `steam_appid.txt` nella
  /// cartella da cui parte il processo, o la variabile `SteamAppId`. Si
  /// mette la variabile solo se manca (lanciato da Steam c'è già).
  static void _setAppIdIfMissing(int appId) {
    if (Platform.environment.containsKey('SteamAppId')) return;
    final name = 'SteamAppId'.toNativeUtf8();
    final value = '$appId'.toNativeUtf8();
    try {
      if (Platform.isWindows) {
        DynamicLibrary.open('kernel32.dll')
            .lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>), int Function(Pointer<Utf8>, Pointer<Utf8>)>(
                'SetEnvironmentVariableA')(name, value);
      } else {
        DynamicLibrary.process()
            .lookupFunction<Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32), int Function(Pointer<Utf8>, Pointer<Utf8>, int)>(
                'setenv')(name, value, 0);
      }
    } catch (_) {
      // Resta steam_appid.txt.
    } finally {
      malloc.free(name);
      malloc.free(value);
    }
  }

  static bool _isSteamRunning(DynamicLibrary lib) =>
      lib.lookupFunction<Bool Function(), bool Function()>('SteamAPI_IsSteamRunning')();

  /// `SteamAPI_InitFlat` (SDK 1.58+), che dice anche perché non va.
  static String? _init(DynamicLibrary lib) {
    final message = calloc<Uint8>(1024);
    try {
      final init = lib.lookupFunction<Int32 Function(Pointer<Uint8>), int Function(Pointer<Uint8>)>('SteamAPI_InitFlat');
      final result = init(message);
      if (result == 0) return null;
      final text = message.cast<Utf8>().toDartString();
      return 'SteamAPI_InitFlat = $result${text.isEmpty ? '' : ' · $text'}';
    } finally {
      calloc.free(message);
    }
  }

  static Pointer<Void> _accessor(DynamicLibrary lib, String base, List<String> versions) {
    for (final version in versions) {
      final name = '${base}_$version';
      if (lib.providesSymbol(name)) {
        return lib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(name)();
      }
    }
    throw StateError('$base: no known interface version');
  }

  /// Lo sportello delle callback (dispatch manuale): serve per il
  /// biglietto, che arriva come `GetTicketForWebApiResponse_t` (168).
  late final _runFrameFn = _lib.lookupFunction<Void Function(Int32), void Function(int)>('SteamAPI_ManualDispatch_RunFrame');
  late final _nextCallback = _lib.lookupFunction<Bool Function(Int32, Pointer<_CallbackMsg>), bool Function(int, Pointer<_CallbackMsg>)>(
      'SteamAPI_ManualDispatch_GetNextCallback');
  late final _freeCallback =
      _lib.lookupFunction<Void Function(Int32), void Function(int)>('SteamAPI_ManualDispatch_FreeLastCallback');

  static const _ticketForWebApiResponse = 168;

  void _runFrame() {
    final message = calloc<_CallbackMsg>();
    try {
      _runFrameFn(_pipe);
      while (_nextCallback(_pipe, message)) {
        try {
          if (message.ref.callback == _ticketForWebApiResponse && message.ref.size >= 12) {
            final data = message.ref.param;
            final handle = data.cast<Uint32>().value;
            final result = (data + 4).cast<Int32>().value;
            final length = (data + 8).cast<Int32>().value;
            final waiting = _waiting.remove(handle);
            if (waiting != null && !waiting.isCompleted) {
              // 1 = k_EResultOK.
              waiting.complete(result == 1 && length > 0 ? Uint8List.fromList((data + 12).asTypedList(length)) : null);
            }
          }
        } finally {
          _freeCallback(_pipe);
        }
      }
    } finally {
      calloc.free(message);
    }
  }

  late final _loggedOn = _lib.lookupFunction<Bool Function(Pointer<Void>), bool Function(Pointer<Void>)>('SteamAPI_ISteamUser_BLoggedOn');

  @override
  bool get running => _pump != null && _loggedOn(_user);

  @override
  String? get problem => running ? null : 'Steam user not logged on';

  @override
  int? get steamId =>
      _lib.lookupFunction<Uint64 Function(Pointer<Void>), int Function(Pointer<Void>)>('SteamAPI_ISteamUser_GetSteamID')(_user);

  @override
  String? get personaName => _lib
      .lookupFunction<Pointer<Utf8> Function(Pointer<Void>), Pointer<Utf8> Function(Pointer<Void>)>(
          'SteamAPI_ISteamFriends_GetPersonaName')(_friends)
      .toDartString();

  @override
  Future<Uint8List?> webApiTicket(String identity, {Duration timeout = const Duration(seconds: 10)}) async {
    final name = identity.toNativeUtf8();
    final int handle;
    try {
      handle = _lib.lookupFunction<Uint32 Function(Pointer<Void>, Pointer<Utf8>), int Function(Pointer<Void>, Pointer<Utf8>)>(
          'SteamAPI_ISteamUser_GetAuthTicketForWebApi')(_user, name);
    } finally {
      malloc.free(name);
    }
    if (handle == 0) return null; // k_HAuthTicketInvalid
    final waiting = _waiting[handle] = Completer<Uint8List?>();
    return waiting.future.timeout(timeout, onTimeout: () {
      _waiting.remove(handle);
      return null;
    });
  }

  bool _byName(String symbol, String achievement) {
    final name = achievement.toNativeUtf8();
    try {
      return _lib.lookupFunction<Bool Function(Pointer<Void>, Pointer<Utf8>), bool Function(Pointer<Void>, Pointer<Utf8>)>(symbol)(
          _stats, name);
    } finally {
      malloc.free(name);
    }
  }

  bool _store() =>
      _lib.lookupFunction<Bool Function(Pointer<Void>), bool Function(Pointer<Void>)>('SteamAPI_ISteamUserStats_StoreStats')(_stats);

  @override
  bool? achieved(String name) {
    final native = name.toNativeUtf8();
    final flag = calloc<Bool>();
    try {
      final ok = _lib.lookupFunction<Bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Bool>),
          bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Bool>)>('SteamAPI_ISteamUserStats_GetAchievement')(_stats, native, flag);
      return ok ? flag.value : null;
    } finally {
      malloc.free(native);
      calloc.free(flag);
    }
  }

  @override
  bool unlock(String name) => _byName('SteamAPI_ISteamUserStats_SetAchievement', name) && _store();

  @override
  bool clear(String name) => _byName('SteamAPI_ISteamUserStats_ClearAchievement', name) && _store();

  @override
  void shutdown() {
    _pump?.cancel();
    _pump = null;
    for (final waiting in _waiting.values) {
      if (!waiting.isCompleted) waiting.complete(null);
    }
    _waiting.clear();
    _lib.lookupFunction<Void Function(), void Function()>('SteamAPI_Shutdown')();
  }
}

/// `CallbackMsg_t`: stessi offset (0, 4, 8, 16) con il pack 8 di Windows e
/// il pack 4 di macOS/Linux, a 64 bit.
final class _CallbackMsg extends Struct {
  @Int32()
  external int user;
  @Int32()
  external int callback;
  external Pointer<Uint8> param;
  @Int32()
  external int size;
}
