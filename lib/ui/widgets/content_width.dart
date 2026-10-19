import 'dart:math';

import 'package:flutter/widgets.dart';

/// Su iPad il contenuto non si allarga da bordo a bordo: resta una colonna
/// centrata, larga al più [maxWidth], e il fondale riempie il resto. Sul
/// telefono non cambia niente. I vincoli restano stretti, come senza.
class ContentWidth extends StatelessWidget {
  /// La larghezza oltre la quale il contenuto smette di crescere.
  static const double tablet = 720;

  final double maxWidth;
  final Widget child;

  const ContentWidth({super.key, this.maxWidth = tablet, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || constraints.maxWidth <= maxWidth) return child;
      final side = (constraints.maxWidth - min(constraints.maxWidth, maxWidth)) / 2;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: child,
      );
    },
  );
}
