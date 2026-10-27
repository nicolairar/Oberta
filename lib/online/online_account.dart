import 'dart:async';

import 'package:flutter/widgets.dart';

import 'online_services.dart';

/// Chi è entrato, visto dal vicolo: l'account e il suo profilo, ricaricato
/// ogni volta che qualcuno entra o esce. Avvisa chi ascolta a ogni cambio.
class OnlineAccount extends ChangeNotifier {
  final OnlineServices services;

  String? _loadedFor;
  Profile? _profile;
  Object? _error;

  OnlineAccount(this.services) {
    _live.add(this);
    services.auth.addListener(_changed);
    _changed();
  }

  static final Set<OnlineAccount> _live = {};

  /// Ricarica il profilo di ogni account aperto: dopo una partita, al
  /// ritorno in primo piano, quando si chiude un foglio o una schermata.
  static void refreshAll() {
    for (final account in _live.toList()) {
      account.refresh();
    }
  }

  Future<void>? _loading;
  StreamSubscription<Wallet>? _wallet;

  /// Il server ha cambiato il saldo: si mostra subito, senza chiedere.
  void _walletArrived(Wallet wallet) {
    final profile = _profile;
    if (profile == null) {
      refresh();
      return;
    }
    _profile = profile.copyWith(level: wallet.level, xp: wallet.xp, coins: wallet.coins);
    notifyListeners();
  }

  bool get signedIn => services.auth.signedIn;

  /// Il profilo di chi è entrato; null finché arriva, o se nessuno è entrato.
  Profile? get profile => signedIn ? _profile : null;

  /// Che cosa è andato storto caricando il profilo.
  Object? get error => _error;

  void _changed() {
    final userId = services.auth.userId;
    if (userId == _loadedFor) {
      notifyListeners();
      return;
    }
    _loadedFor = userId;
    _profile = null;
    _error = null;
    _wallet?.cancel();
    _wallet = null;
    BlockedPlayers.clear();
    notifyListeners();
    if (userId != null) {
      refresh();
      // Chi si è bloccato, per nasconderne subito i messaggi.
      services.safety?.blocked().ignore();
      _wallet = services.profiles.watchWallet().listen(_walletArrived, onError: (_) {});
    }
  }

  /// Chiede di nuovo `my_profile()`: livello, esperienza e monete freschi.
  /// Più richieste insieme diventano una sola.
  Future<void> refresh() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    final userId = services.auth.userId;
    if (userId == null) return;
    _error = null;
    try {
      final profile = await services.profiles.me();
      if (services.auth.userId != userId) return;
      _profile = profile;
      WornLooks.remember(profile);
      PlayerMarks.remember(profile);
      _refreshSteam(userId, profile);
    } catch (error) {
      if (services.auth.userId != userId) return;
      _error = error;
    }
    notifyListeners();
  }

  String? _steamAskedFor;

  /// Una volta per sessione, chi gioca con Steam chiede al server di rileggere
  /// nome e immagine di Steam (il server lo fa al massimo ogni sei ore).
  void _refreshSteam(String userId, Profile profile) {
    if (!profile.onSteam || _steamAskedFor == userId) return;
    _steamAskedFor = userId;
    services.profiles.refreshSteam().then((changed) {
      if (changed && services.auth.userId == userId) refresh();
    }, onError: (_) {});
  }

  /// Il profilo appena salvato, senza tornare a chiederlo al server.
  void saved(Profile profile) {
    _profile = profile;
    WornLooks.remember(profile);
    PlayerMarks.remember(profile);
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _live.remove(this);
    _wallet?.cancel();
    services.auth.removeListener(_changed);
    super.dispose();
  }
}

/// Ogni volta che si chiude una schermata o un foglio (i risultati della
/// partita, la stanza, il negozio), il profilo torna a chiedersi al server.
class AccountRefreshObserver extends NavigatorObserver {
  static final instance = AccountRefreshObserver();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => OnlineAccount.refreshAll();
}
