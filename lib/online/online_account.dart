import 'package:flutter/foundation.dart';

import 'online_services.dart';

/// Chi è entrato, visto dal vicolo: l'account e il suo profilo, ricaricato
/// ogni volta che qualcuno entra o esce. Avvisa chi ascolta a ogni cambio.
class OnlineAccount extends ChangeNotifier {
  final OnlineServices services;

  String? _loadedFor;
  Profile? _profile;
  Object? _error;

  OnlineAccount(this.services) {
    services.auth.addListener(_changed);
    _changed();
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
    notifyListeners();
    if (userId != null) refresh();
  }

  Future<void> refresh() async {
    final userId = services.auth.userId;
    if (userId == null) return;
    _error = null;
    try {
      final profile = await services.profiles.me();
      if (services.auth.userId != userId) return;
      _profile = profile;
      WornLooks.remember(profile);
    } catch (error) {
      if (services.auth.userId != userId) return;
      _error = error;
    }
    notifyListeners();
  }

  /// Il profilo appena salvato, senza tornare a chiederlo al server.
  void saved(Profile profile) {
    _profile = profile;
    WornLooks.remember(profile);
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    services.auth.removeListener(_changed);
    super.dispose();
  }
}
