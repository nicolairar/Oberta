import 'dart:async';

import '../settings/app_settings.dart';
import '../tutorial/tutorial_story.dart';
import 'online_services.dart';

/// Le mani di prova finite vanno al server: la classificata le chiede tutte
/// e tre (`tutorial_complete`). Sul telefono restano anche offline
/// ([AppSettings.tutorialsDone]); appena si è dentro, quelle che il server
/// non ha ancora si mandano.
class TutorialSync {
  final OnlineServices services;
  final AppSettings Function() settings;

  TutorialSync(this.services, {AppSettings Function()? settings}) : settings = settings ?? (() => AppSettings.instance);

  static TutorialSync? instance;

  /// Collega [TutorialProgress.onComplete] e l'ingresso nell'account.
  static TutorialSync attach(OnlineServices services) {
    final sync = instance = TutorialSync(services);
    TutorialProgress.onComplete = (story) => unawaited(sync.complete(story));
    services.auth.addListener(() {
      if (services.auth.signedIn) unawaited(sync.upload(const {}));
    });
    if (services.auth.signedIn) unawaited(sync.upload(const {}));
    return sync;
  }

  /// Registra una mano finita, se si è dentro. Gli errori (rete, profilo
  /// senza nome) si ignorano: la prossima [upload] riprova.
  Future<void> complete(TutorialStory story) async {
    final ranked = services.ranked;
    if (ranked == null || !services.auth.signedIn) return;
    try {
      await ranked.completeTutorial(story.id);
    } catch (_) {}
  }

  /// Manda le mani finite sul telefono che mancano in [server]. Vero se ne
  /// ha mandata almeno una.
  Future<bool> upload(Set<String> server) async {
    final ranked = services.ranked;
    if (ranked == null || !services.auth.signedIn) return false;
    var sent = false;
    for (final id in settings().tutorialsDone) {
      if (server.contains(id) || TutorialStory.byId(id) == null) continue;
      try {
        await ranked.completeTutorial(id);
        sent = true;
      } catch (_) {
        return sent;
      }
    }
    return sent;
  }

  /// Le mani fatte da mostrare: quelle del server più quelle del telefono.
  static Set<TutorialStory> done(Set<String> server, AppSettings settings) => {
        for (final id in {...server, ...settings.tutorialsDone}) ?TutorialStory.byId(id),
      };
}
