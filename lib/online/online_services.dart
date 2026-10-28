import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';
import 'app_update.dart';
import 'device_session.dart';
import 'game/game_backend.dart';
import 'online_models.dart';
import 'progress_models.dart';
import 'ranked_models.dart';
import 'reactions.dart';
import 'safety.dart';
import 'shop_models.dart';

export 'app_update.dart';
export 'device_session.dart';
export 'game/game_backend.dart';
export 'online_models.dart';
export 'progress_models.dart';
export 'ranked_models.dart';
export 'reactions.dart';
export 'safety.dart';
export 'shop_models.dart';

/// L'account: chi è entrato, e come si entra. Avvisa chi ascolta quando
/// qualcuno entra o esce.
///
/// Si entra solo con un account vero, Apple o Google, così il profilo segue
/// la persona su ogni telefono. Niente email, niente password.
abstract class OnlineAuth extends ChangeNotifier {
  /// L'id dell'account, o null se nessuno è entrato.
  String? get userId;

  bool get signedIn => userId != null;

  /// Sign in with Apple si offre solo dove c'è (iPhone).
  bool get appleAvailable;

  /// Google si offre solo se l'app è stata compilata con i suoi client id.
  bool get googleAvailable;

  /// Il nome che Apple o Google hanno dato all'accesso, da proporre nel profilo.
  String? get suggestedName;

  Future<void> signInWithApple();

  Future<void> signInWithGoogle();

  /// «Accedi con Steam», solo sull'app desktop (OpenID nel browser).
  bool get steamAvailable => false;

  Future<void> signInWithSteam() async => throw const OnlineException(OnlineFailure.unknown, null, 'steam · unavailable');

  /// L'account di prova, con email e password, per chi prova l'app da un
  /// secondo telefono: entra, o crea l'account se non c'è ancora. Nascosto
  /// ai giocatori (si apre tenendo premuto «Accedi»); sul server va acceso
  /// il provider Email, con la conferma via email spenta.
  Future<void> signInWithTestAccount({required String email, required String password});

  Future<void> signOut();
}

abstract class ProfileRepository {
  /// Il profilo di chi è entrato, con livello, esperienza e monete.
  Future<Profile> me();

  /// Il proprio portafoglio, spinto dal server a ogni cambio (partite,
  /// acquisti, regali). Sola lettura: il client non scrive mai i saldi.
  Stream<Wallet> watchWallet();

  Future<Profile> update({required String handle, AppLanguage? language});

  /// Salva i lineamenti gratuiti dello specchio del barbiere ([face], con le
  /// chiavi di `FaceFeatures.keys`) e la pelle [tone]. I pezzi della bottega
  /// non si toccano; [mark] è il segno che l'app mostra a chi non ne ha mai
  /// salvato uno (vale solo se è di base).
  Future<Profile> saveFace(Map<String, String> face, {required String tone, String? mark});

  /// L'immagine del profilo: il ritratto del gioco o quella di Steam.
  Future<Profile> setPicture(ProfilePicture picture);

  /// Chiede al server di rileggere nome e immagine di Steam. Vero se li ha
  /// riletti (allora conviene ricaricare il profilo).
  Future<bool> refreshSteam();

  /// Vero se nessun altro ha già questo nome unico (in qualunque maiuscola).
  Future<bool> handleAvailable(String handle);

  /// I profili il cui nome unico comincia così, tranne il proprio.
  Future<List<Profile>> search(String handlePrefix);

  /// Il fascicolo pubblico di un altro giocatore, per nome unico o id.
  /// `notAllowed` se uno dei due ha bloccato l'altro.
  Future<PublicProfile> publicProfile(String handleOrId);

  /// «Profilo pubblico»: spento, gli altri vedono solo nome, livello e ritratto.
  Future<Profile> setPublicProfile(bool visible);

  /// «Gesti al tavolo»: spenti, nessuno può lanciargliene.
  Future<Profile> setTableReactions(bool on);
}

abstract class FriendsRepository {
  /// Amici, richieste ricevute e richieste mandate.
  Future<List<Friendship>> list();

  /// Chiede l'amicizia; se l'altro l'aveva già chiesta, la accetta.
  Future<FriendStatus> request(String profileId);

  Future<void> respond(String requesterId, {required bool accept});

  /// Toglie un amico o ritira una richiesta mandata.
  Future<void> remove(String profileId);
}

abstract class RoomRepository {
  Future<Room> create(AppLanguage language);

  Future<Room> join(String code);

  /// Esce dalla stanza. Il padrone di casa, se c'è altra gente, deve dire a
  /// chi lasciarla ([newHostId]); [autoHeir] la passa al primo arrivato, per
  /// quando si esce senza un gesto (l'app che si chiude).
  Future<void> leave(String roomId, {String? newHostId, bool autoHeir = false});

  /// La stanza com'è adesso, o null se non la si vede più.
  Future<Room?> fetch(String roomId);

  /// Chi siede nella stanza, aggiornato ogni volta che qualcuno entra o esce
  /// (e quando la stanza cambia: i bot, la partita che comincia).
  Stream<List<RoomMember>> watchMembers(String roomId);

  /// La stanza in cui si siede adesso, se c'è: per rientrare al tavolo dopo
  /// aver chiuso l'app.
  Future<Room?> current();
}

/// I dati e la vita dell'account: scaricare tutto quello che il server
/// tiene di chi è entrato, ed eliminare l'account per sempre.
abstract class AccountRepository {
  /// Tutti i dati di chi è entrato (profilo, amici, armadio, monete, stanze,
  /// messaggi, abbandoni), come un documento JSON.
  Future<Map<String, dynamic>> exportData();

  /// Elimina l'account e i dati personali, poi esce. Gli acquisti con soldi
  /// veri restano solo come ricevute anonime (vedi la migrazione
  /// 20261019150000_account_privacy.sql).
  Future<void> deleteAccount();
}

/// Le identità che si collegano a un account già entrato.
enum LinkProvider {
  steam('Steam'),
  apple('Apple'),
  google('Google');

  final String label;

  const LinkProvider(this.label);
}

/// «Collega account», senza codici: si entra con l'altra identità (Apple o
/// Google dal desktop, Steam dal telefono) nel browser di sistema, e il
/// server unisce i due profili (resta il più vecchio).
abstract class AccountLinkRepository {
  /// Che cosa si può collegare da questo dispositivo.
  List<LinkProvider> get providers;

  /// Collega [provider]. Vero se adesso si è dentro un altro profilo (quello
  /// più vecchio, che è rimasto): l'app è già entrata lì da sola.
  Future<bool> link(LinkProvider provider);
}

/// Tutto quello che serve per giocare online. Null dove l'app è stata
/// compilata senza la configurazione di Supabase: lì l'online non c'è.
class OnlineServices {
  final OnlineAuth auth;
  final ProfileRepository profiles;
  final FriendsRepository friends;
  final RoomRepository rooms;
  final GameBackend game;

  /// La bottega dei cosmetici. Null dove nessuno l'ha collegata.
  final ShopRepository? shop;

  /// La classificata e i risultati delle partite. Null dove non c'è.
  final RankedRepository? ranked;

  /// Esportare i dati ed eliminare l'account. Null dove nessuno l'ha collegato.
  final AccountRepository? account;

  /// Segnalare e bloccare giocatori. Null dove nessuno l'ha collegato.
  final SafetyRepository? safety;

  /// Un dispositivo alla volta. Null dove nessuno l'ha collegato.
  final DeviceSessionRepository? sessions;

  /// Collegare gli account fra telefono e desktop. Null dove non c'è.
  final AccountLinkRepository? links;

  /// Missions, achievements and the leaderboard. Null where there is none.
  final ProgressRepository? progress;

  /// La build minima chiesta dal server. Null dove non c'è.
  final AppRequirementsRepository? requirements;

  /// I gesti del tavolo. Null dove non ci sono.
  final ReactionsRepository? reactions;

  const OnlineServices({
    required this.auth,
    required this.profiles,
    required this.friends,
    required this.rooms,
    required this.game,
    this.shop,
    this.account,
    this.ranked,
    this.safety,
    this.sessions,
    this.links,
    this.progress,
    this.requirements,
    this.reactions,
  });

  static OnlineServices? instance;
}
