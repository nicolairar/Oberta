import 'package:flutter/material.dart';

import '../../rules/role.dart';

extension RoleStyle on Role {
  Color get color => switch (this) {
        Role.mafioso => const Color(0xFF8E1620),
        Role.cittadino => const Color(0xFF4A5560),
        Role.detective => const Color(0xFF1F4E79),
        Role.medico => const Color(0xFF1E6B52),
        Role.cecchino => const Color(0xFF6B4A1E),
        Role.giornalista => const Color(0xFF5B3A78),
      };

  IconData get icon => switch (this) {
        Role.mafioso => Icons.theater_comedy,
        Role.cittadino => Icons.person,
        Role.detective => Icons.search,
        Role.medico => Icons.medical_services,
        Role.cecchino => Icons.gps_fixed,
        Role.giornalista => Icons.newspaper,
      };
}
