import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';
import 'online_models.dart';

export 'online_models.dart';

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

  Future<Profile> update({required String handle, required String displayName, AppLanguage? language});

  /// Vero se nessun altro ha già questo nome unico (in qualunque maiuscola).
  Future<bool> handleAvailable(String handle);

  /// I profili il cui nome unico comincia così, tranne il proprio.
  Future<List<Profile>> search(String handlePrefix);
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

  /// Chi siede nella stanza, aggiornato ogni volta che qualcuno entra o esce.
  Stream<List<RoomMember>> watchMembers(String roomId);
}

/// Tutto quello che serve per giocare online. Null dove l'app è stata
/// compilata senza la configurazione di Supabase: lì l'online non c'è.
class OnlineServices {
  final OnlineAuth auth;
  final ProfileRepository profiles;
  final FriendsRepository friends;
  final RoomRepository rooms;

  const OnlineServices({required this.auth, required this.profiles, required this.friends, required this.rooms});

  static OnlineServices? instance;
}
