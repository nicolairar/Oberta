import 'package:flutter/widgets.dart';

/// Dove sta l'uomo su una pagina della strada: i piedi e l'altezza. Nel
/// vicolo è il fumatore sotto il lampione; davanti a un locale è la soglia
/// della porta, dove entra ed esce.
@immutable
class StreetSpot {
  final Offset feet;
  final double height;

  /// La porta, se c'è: l'uomo ci entra e ne esce.
  final Rect? door;

  const StreetSpot(this.feet, this.height, {this.door});

  @override
  bool operator ==(Object other) =>
      other is StreetSpot && other.feet == feet && other.height == height && other.door == door;

  @override
  int get hashCode => Object.hash(feet, height, door);
}

/// Il palco comune della strada: chi sta camminando e dove si trova l'uomo
/// su ogni pagina. Le pagine dicono il loro posto quando si disegnano; la
/// strada (vedi `StreetRoute`) le legge per la camminata.
abstract final class StreetStage {
  /// Quante camminate sono in corso: finché ce n'è una, l'uomo fermo del
  /// vicolo non si disegna (lo disegna chi cammina).
  static final ValueNotifier<int> walking = ValueNotifier(0);

  static final _spots = Expando<StreetSpot>('street spot');

  /// La pagina di [context] dice dove sta l'uomo.
  static void report(BuildContext context, StreetSpot spot) {
    final route = ModalRoute.of(context);
    if (route != null) _spots[route] = spot;
  }

  static StreetSpot? spotOf(Route<dynamic>? route) => route == null ? null : _spots[route];
}
