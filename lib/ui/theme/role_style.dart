import 'package:flutter/material.dart';

import '../../rules/role.dart';

extension RoleStyle on Role {
  /// La famiglia sta sui rossi, ognuno col suo; gli onesti si dividono il
  /// resto della tavolozza.
  Color get color => switch (this) {
        Role.mafioso => const Color(0xFF8E1620),
        Role.padrino => const Color(0xFF5C0F2E),
        Role.sarto => const Color(0xFF8A2F5A),
        Role.compare => const Color(0xFF7A3B2E),
        Role.cittadino => const Color(0xFF4A5560),
        Role.detective => const Color(0xFF1F4E79),
        Role.medico => const Color(0xFF1E6B52),
        Role.cecchino => const Color(0xFF6B4A1E),
        Role.giornalista => const Color(0xFF5B3A78),
        Role.becchino => const Color(0xFF3B4636),
        Role.guardaspalle => const Color(0xFF256A73),
        Role.reduce => const Color(0xFF5E6426),
        Role.pregiudicato => const Color(0xFFA0561C),
        Role.messia => const Color(0xFF8C7A3A),
        Role.sindaco => const Color(0xFF2E5E8C),
        Role.portinaio => const Color(0xFF55606B),
        Role.fesso => const Color(0xFFB08A1E),
        Role.piromane => const Color(0xFFC0471A),
      };

  IconData get icon => switch (this) {
        Role.mafioso => Icons.theater_comedy,
        Role.padrino => Icons.smoking_rooms,
        Role.sarto => Icons.content_cut,
        Role.compare => Icons.forum,
        Role.cittadino => Icons.person,
        Role.detective => Icons.search,
        Role.medico => Icons.medical_services,
        Role.cecchino => Icons.gps_fixed,
        Role.giornalista => Icons.newspaper,
        Role.becchino => Icons.church,
        Role.guardaspalle => Icons.shield,
        Role.reduce => Icons.military_tech,
        Role.pregiudicato => Icons.fingerprint,
        Role.messia => Icons.wb_twilight,
        Role.sindaco => Icons.account_balance,
        Role.portinaio => Icons.door_front_door,
        Role.fesso => Icons.sentiment_very_satisfied,
        Role.piromane => Icons.local_fire_department,
      };
}
