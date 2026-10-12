import 'player.dart';
import 'role.dart';

/// A chi è destinata un'informazione sul ruolo di qualcuno.
enum Visibility {
  /// Solo il diretto interessato (il proprio ruolo).
  private,

  /// Una squadra che si conosce (i mafiosi tra loro).
  team,

  /// Chi se l'è guadagnata (l'esito di un'indagine).
  acquired,

  /// Tutti (il ruolo di un linciato, uno scoop del giornale).
  public,
}

/// Un'informazione su [subject]: almeno la fazione, a volte il ruolo esatto.
/// Ogni evento del gioco che svela qualcosa aggiunge un fatto e dichiara chi
/// lo può vedere: un ruolo nuovo cambia i fatti, non il motore.
class Fact {
  final Player subject;
  final Team team;
  final Role? role;
  final Visibility visibility;
  final Set<Player> audience;

  const Fact({
    required this.subject,
    required this.team,
    this.role,
    required this.visibility,
    this.audience = const {},
  });

  bool visibleTo(Player? viewer) =>
      visibility == Visibility.public || (viewer != null && audience.contains(viewer));
}

/// Quello che un certo giocatore sa di un altro.
class Knowledge {
  final Role? role;
  final Team? team;

  const Knowledge({this.role, this.team});

  static const none = Knowledge();

  bool get isEmpty => team == null;
}
