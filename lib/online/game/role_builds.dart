import '../../rules/role.dart';

// The server deals the cards, but a phone has to read them: a build that
// does not know a role cannot parse a table where it is dealt (the deck, its
// own card, the final reveal) and stays stuck on "connecting". So a role
// added after the first online builds is dealt only when every person at the
// table runs a build that knows it.
//
// The database records each player's build (the x-app-build header) when
// they create, join or queue for a room (internal.client_builds, migration
// 20261121090000_client_builds.sql); the Edge Function passes the lowest one
// at the table as `minBuild` when it deals.
//
// Adding a role: put it here with the first build that ships it (the +N of
// pubspec "version: x.y.z+N" of the next TestFlight/release).

/// The roles every online build knows (build 65 and before).
const baselineRoles = {
  Role.mafioso,
  Role.padrino,
  Role.sarto,
  Role.compare,
  Role.cittadino,
  Role.detective,
  Role.medico,
  Role.cecchino,
  Role.giornalista,
  Role.becchino,
  Role.guardaspalle,
  Role.reduce,
  Role.pregiudicato,
  Role.messia,
  Role.sindaco,
  Role.portinaio,
  Role.fesso,
  Role.piromane,
  Role.cacciatore,
  Role.strozzino,
  Role.sicario,
};

/// The first build that knows each role added after [baselineRoles].
const roleSinceBuild = <Role, int>{
  Role.prostituta: 66,
  Role.carceriere: 66,
  Role.pacifista: 66,
  Role.cupido: 66,
};

/// The roles a table whose oldest build is [minBuild] cannot be dealt.
/// `null` (no person at the table, or a test): every role.
Set<Role> rolesTooNewFor(int? minBuild) {
  if (minBuild == null) return const {};
  return {
    for (final role in Role.values)
      if (!baselineRoles.contains(role) && minBuild < (roleSinceBuild[role] ?? 1 << 30)) role,
  };
}
