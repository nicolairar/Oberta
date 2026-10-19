import 'game_engine.dart';
import 'game_settings.dart';
import 'game_setup.dart';
import 'knowledge.dart';
import 'player.dart';
import 'role.dart';

/// JSON per i tipi del motore. Nel JSON una persona è sempre e solo il suo
/// posto (`Player.id`): niente nomi, che stanno fuori dal motore.

/// Da un id di posto al [Player] che lo occupa. Chi riprende una partita
/// può passare il suo (es. `Seating.playerAt`) per riavere i nomi.
typedef SeatResolver = Player Function(String seat);

/// Il resolver di base: il posto fa anche da nome.
Player seatPlayer(String seat) => Player(id: seat, name: seat);

String? seatOf(Player? player) => player?.id;

Player? optionalSeat(Object? json, SeatResolver resolve) => json == null ? null : resolve(json as String);

List<String> seatsOf(Iterable<Player> players) => [for (final player in players) player.id];

List<Player> seatsFrom(Object? json, SeatResolver resolve) => [
      for (final seat in json as List<Object?>) resolve(seat as String),
    ];

T? optionalEnum<T extends Enum>(List<T> values, Object? json) => json == null ? null : values.byName(json as String);

Map<String, Object?> settingsToJson(GameSettings settings) => {
      'mafiaTieBreak': settings.mafiaTieBreak.name,
      'nightMs': settings.night.inMilliseconds,
      'discussionMs': settings.discussion.inMilliseconds,
      'voteMs': settings.vote.inMilliseconds,
    };

/// Le partite salvate prima dei timer hanno solo la discussione; un vecchio
/// spareggio "boss" (voto doppio, tolto) diventa un sorteggio.
GameSettings settingsFromJson(Map<String, Object?> json) => GameSettings(
      mafiaTieBreak: json['mafiaTieBreak'] == TieBreak.nobody.name ? TieBreak.nobody : TieBreak.random,
      night: Duration(milliseconds: json['nightMs'] as int? ?? GameSettings.defaultNight.inMilliseconds),
      discussion: Duration(milliseconds: json['discussionMs'] as int),
      vote: Duration(milliseconds: json['voteMs'] as int? ?? GameSettings.defaultVote.inMilliseconds),
    );

/// Il tavolo: i posti in ordine, ciascuno con il suo ruolo.
Map<String, Object?> setupToJson(GameSetup setup) => {
      'narrator': seatOf(setup.narrator),
      'seats': [
        for (final entry in setup.roles.entries) {'seat': entry.key.id, 'role': entry.value.name},
      ],
    };

GameSetup setupFromJson(Map<String, Object?> json, SeatResolver resolve) => GameSetup.fromRoles({
      for (final seat in (json['seats'] as List<Object?>).cast<Map<String, Object?>>())
        resolve(seat['seat'] as String): Role.values.byName(seat['role'] as String),
    }, narrator: optionalSeat(json['narrator'], resolve));

Map<String, Object?> factToJson(Fact fact) => {
      'subject': fact.subject.id,
      'team': fact.team.name,
      'role': fact.role?.name,
      'visibility': fact.visibility.name,
      'audience': seatsOf(fact.audience),
      'apparent': fact.apparent,
    };

Fact factFromJson(Map<String, Object?> json, SeatResolver resolve) => Fact(
      subject: resolve(json['subject'] as String),
      team: Team.values.byName(json['team'] as String),
      role: optionalEnum(Role.values, json['role']),
      visibility: Visibility.values.byName(json['visibility'] as String),
      audience: seatsFrom(json['audience'], resolve).toSet(),
      apparent: json['apparent'] as bool,
    );

Map<String, Object?> exposureToJson(Exposure exposure) => {
      'seat': exposure.subject.id,
      'team': exposure.team.name,
      if (exposure.role != null) 'role': exposure.role!.name,
    };

Exposure exposureFromJson(Map<String, Object?> json, SeatResolver resolve) => Exposure(
      resolve(json['seat'] as String),
      Team.values.byName(json['team'] as String),
      role: optionalEnum(Role.values, json['role']),
    );

Map<String, Object?> attackToJson(NightAttack attack) => {
      'target': attack.target.id,
      'source': attack.source.name,
      'outcome': attack.outcome.name,
    };

NightAttack attackFromJson(Map<String, Object?> json, SeatResolver resolve) => NightAttack(
      resolve(json['target'] as String),
      AttackSource.values.byName(json['source'] as String),
      AttackOutcome.values.byName(json['outcome'] as String),
    );

Map<String, Object?> dawnToJson(DawnReport dawn) => {
      'round': dawn.round,
      'attacks': [for (final attack in dawn.attacks) attackToJson(attack)],
      'scoop': dawn.scoop == null ? null : exposureToJson(dawn.scoop!),
      'silenced': seatOf(dawn.silenced),
      if (dawn.resurrected != null) 'resurrected': seatOf(dawn.resurrected),
      'winner': dawn.winner?.name,
    };

DawnReport dawnFromJson(Map<String, Object?> json, SeatResolver resolve) => DawnReport(
      round: json['round'] as int,
      attacks: [
        for (final attack in (json['attacks'] as List<Object?>).cast<Map<String, Object?>>())
          attackFromJson(attack, resolve),
      ],
      scoop: json['scoop'] == null ? null : exposureFromJson(json['scoop'] as Map<String, Object?>, resolve),
      silenced: optionalSeat(json['silenced'], resolve),
      resurrected: optionalSeat(json['resurrected'], resolve),
      winner: optionalEnum(Team.values, json['winner']),
    );

Map<String, Object?> lynchToJson(LynchReport lynch) => {
      'round': lynch.round,
      'condemned': seatOf(lynch.condemned),
      'role': lynch.role?.name,
      'winner': lynch.winner?.name,
      if (lynch.personalWin) 'personalWin': true,
      if (lynch.bountyHunter != null) 'bountyHunter': seatOf(lynch.bountyHunter),
    };

LynchReport lynchFromJson(Map<String, Object?> json, SeatResolver resolve) => LynchReport(
      round: json['round'] as int,
      condemned: optionalSeat(json['condemned'], resolve),
      role: optionalEnum(Role.values, json['role']),
      winner: optionalEnum(Team.values, json['winner']),
      personalWin: json['personalWin'] as bool? ?? false,
      bountyHunter: optionalSeat(json['bountyHunter'], resolve),
    );

Map<String, Object?> roundToJson(RoundRecord record) => {
      'round': record.round,
      'nightVictims': seatsOf(record.nightVictims),
      'lynched': seatOf(record.lynched),
    };

RoundRecord roundFromJson(Map<String, Object?> json, SeatResolver resolve) => RoundRecord(
      round: json['round'] as int,
      nightVictims: seatsFrom(json['nightVictims'], resolve),
      lynched: optionalSeat(json['lynched'], resolve),
    );
