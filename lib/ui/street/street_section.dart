import 'package:flutter/widgets.dart';

import '../../l10n/app_language.dart';
import '../../l10n/app_strings.dart';

/// Che porta c'è sulla strada: la vetrina della bottega, il palo del
/// barbiere, la porta imbottita del retrobottega, il caffè, l'ufficio, la
/// sala da gioco della classificata (verde bottiglia, il cordone di velluto).
enum StreetFront { shop, barber, club, cafe, office, hall }

/// I posti lungo la strada dei menu. Ognuno ha la sua insegna (più piccola
/// e d'un altro colore rispetto a OBERTÀ, che resta l'unica rossa), la sua
/// facciata e il nome nelle due lingue.
enum StreetSection {
  friends('AMICI', 'FRIENDS', Color(0xFF3D7BFF), StreetFront.cafe),
  join('ENTRA', 'JOIN', Color(0xFF3DD6FF), StreetFront.club),
  crew('COMPARI', 'CREW', Color(0xFFB07BFF), StreetFront.cafe),
  ranked('CLASSIFICATA', 'RANKED', Color(0xFFFF3DA8), StreetFront.hall),
  shop('BOTTEGA', 'SHOP', Color(0xFFFFB443), StreetFront.shop),
  barber('BARBIERE', 'BARBER', Color(0xFF5CD2FF), StreetFront.barber),
  settings('IMPOSTAZIONI', 'SETTINGS', Color(0xFF3DFFB4), StreetFront.office),
  leaderboard('CLASSIFICA', 'LEADERS', Color(0xFFC27BFF), StreetFront.club),
  missions('MISSIONI', 'MISSIONS', Color(0xFF7BFF6A), StreetFront.office),
  achievements('TROFEI', 'TROPHIES', Color(0xFFFFE15C), StreetFront.office);

  final String it;
  final String en;

  /// Il colore dei tubi: blu da locale notturno, ambra, rosa, verde...
  final Color neon;
  final StreetFront front;

  const StreetSection(this.it, this.en, this.neon, this.front);

  String name(AppLanguage language) => language == AppLanguage.it ? it : en;

  String nameOf(BuildContext context) => name(AppStrings.of(context).language);
}
