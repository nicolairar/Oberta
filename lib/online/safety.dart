import 'package:flutter/foundation.dart';

import 'online_models.dart';

/// Perché si segnala qualcuno. Il nome è quello che il server si aspetta
/// (`report_player`, colonna `reason`).
enum ReportReason {
  /// Linguaggio offensivo.
  language,

  /// Barare o abbandonare le partite.
  cheating,

  /// Nome o aspetto inappropriato.
  identity,
  spam,
  other,
}

/// Segnalare e bloccare: quello che Apple chiede a ogni app dove la gente si
/// scrive (linea guida 1.2). Chi è segnalato non sa mai da chi.
abstract class SafetyRepository {
  /// Segnala [targetId]. [messageId] è il messaggio della chat che si
  /// segnala, se c'è: il server ne tiene una copia. Una seconda segnalazione
  /// dello stesso giocatore nello stesso giorno passa in silenzio.
  Future<void> report(String targetId, ReportReason reason, {String? note, String? gameId, String? messageId});

  /// I giocatori che si sono bloccati. Aggiorna anche [BlockedPlayers].
  Future<List<Profile>> blocked();

  /// Blocca: i suoi messaggi spariscono, l'amicizia finisce, non può più
  /// chiederla né sedersi nelle stanze di chi l'ha bloccato.
  Future<void> block(String profileId);

  Future<void> unblock(String profileId);
}

/// Chi questo telefono ha bloccato, per nascondere subito i suoi messaggi
/// (il server li toglie comunque dalla chat che manda).
abstract final class BlockedPlayers {
  static final ValueNotifier<Set<String>> ids = ValueNotifier(const {});

  static void set(Iterable<String> profileIds) => ids.value = Set.unmodifiable(profileIds);

  static void add(String id) => set({...ids.value, id});

  static void remove(String id) => set({...ids.value}..remove(id));

  /// Chi si è silenziato nella chat, solo su questo telefono e finché l'app
  /// resta aperta: i suoi messaggi non si vedono, ma resta tutto il resto
  /// (niente blocco, niente segnalazione, lui non lo sa).
  static final ValueNotifier<Set<String>> chatMuted = ValueNotifier(const {});

  static bool chatMutes(String id) => chatMuted.value.contains(id);

  static void toggleChat(String id) => chatMuted.value =
      Set.unmodifiable(chatMutes(id) ? ({...chatMuted.value}..remove(id)) : {...chatMuted.value, id});

  /// Cambia quando cambia chi si nasconde: bloccati o silenziati.
  static final Listenable changes = Listenable.merge([ids, chatMuted]);

  /// Solo i messaggi di chi non è bloccato né silenziato.
  static List<T> visible<T>(List<T> items, String Function(T item) profileOf) {
    final hidden = {...ids.value, ...chatMuted.value};
    if (hidden.isEmpty) return items;
    return [
      for (final item in items)
        if (!hidden.contains(profileOf(item))) item,
    ];
  }

  /// Per i test.
  static void clear() {
    ids.value = const {};
    chatMuted.value = const {};
  }
}
