import '../l10n/app_language.dart';
import 'shop_models.dart';

/// I gesti del tavolo: si lanciano al posto di un altro e volano sul panno.
/// L'id è il `look_id` del pezzo `gesture.<id>` della bottega, e quello che
/// il server scrive in `table_reactions.reaction`.
enum TableGesture {
  cigar,
  toast,
  hatTip,
  omerta,
  eye,
  coin,
  fish,
  gun,
  cash,
  rose,
  kiss,
  horse,
  tommy;

  static TableGesture? byId(String? id) => values.where((g) => g.name == id).firstOrNull;

  /// Il pezzo della bottega.
  ShopItem get item => gestureDrop.firstWhere((item) => item.lookId == name);

  /// Di casa: lo possiedono tutti.
  bool get free => item.free;

  /// I leggendari hanno la scena lunga, all'arrivo.
  bool get legendary => item.rarity == ShopRarity.leggendario;

  String label(AppLanguage language) => item.name(language);
}

/// Le regole dei gesti, le stesse del server (`send_reaction`).
abstract final class ReactionRules {
  /// Fra un gesto e il seguente.
  static const cooldown = Duration(seconds: 8);

  /// Al massimo per partita.
  static const perGame = 40;
}

/// Un gesto lanciato: da un posto a un altro. Al tavolo i posti sono quelli
/// della partita (`s3`); nella stanza d'attesa il numero della sedia (`3`).
class TableReaction {
  final int id;
  final String profileId;
  final String fromSeat;
  final String toSeat;
  final TableGesture gesture;
  final DateTime at;

  const TableReaction({
    required this.id,
    required this.profileId,
    required this.fromSeat,
    required this.toSeat,
    required this.gesture,
    required this.at,
  });

  /// Null se il gesto è di una versione più nuova dell'app.
  static TableReaction? fromJson(Map<String, Object?> json) {
    final gesture = TableGesture.byId(json['reaction'] as String?);
    if (gesture == null) return null;
    return TableReaction(
      id: (json['id'] as num).toInt(),
      profileId: json['profile_id'] as String,
      fromSeat: json['from_seat'] as String,
      toSeat: json['to_seat'] as String,
      gesture: gesture,
      at: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// I gesti di una stanza. Il server controlla tutto: la fase (mai di notte),
/// chi è vivo, l'attesa fra un gesto e l'altro, il tetto per partita, i
/// blocchi, chi li ha spenti e i gesti comprati.
abstract class ReactionsRepository {
  /// Lancia [gesture] al posto [toSeat]. Null se il bersaglio non li riceve
  /// (il gesto non parte, ma chi lo lancia non lo sa).
  Future<int?> send(String roomId, String toSeat, TableGesture gesture);

  /// Gli ultimi gesti della stanza, man mano che arrivano.
  Stream<List<TableReaction>> watch(String roomId);

  /// I gesti a pagamento posseduti (quelli di casa ci sono sempre).
  Future<Set<TableGesture>> owned();
}
