// The game's events in the chat: short system lines the server writes next
// to the players' messages. They are computed only from what the server
// publishes anyway (the public board and each seat's own view), never from
// the secret state: a public event says nothing the board does not say,
// and a private one ("only you") nothing its seat's view does not say.
//
// Each event is `{to, kind, data}`: `to` null for the whole table, or the
// seat that alone may read it (the database stores it for that profile and
// its policy shows it to nobody else). `data` carries names and enum names
// only; the phones word it in their language.
//
// Public kinds: night, dawn, scoop, silenced, lynch, mayor, truce, left, end.
// Private kinds: found, watch, bounty, doused, familyTarget, protected,
// cell (who is in the cell tonight: the prisoner, or a Family member about
// one of theirs), busy (the Prostitute kept you busy last night), lovers
// (Cupid's couple: to Cupid, and to the two lovers from the first dawn).

/// What the table has already been told, so that a line is written once.
/// Kept in the server state between steps.
class EventMarks {
  int night;
  int dawn;
  int lynch;
  bool end;

  /// The final tally of the last vote, read off the public board when the
  /// vote closed, waiting for the verdict to be told.
  Map<String, Object?>? tally;

  EventMarks({this.night = 0, this.dawn = 0, this.lynch = 0, this.end = false, this.tally});

  factory EventMarks.fromJson(Map<String, Object?>? json) => json == null
      ? EventMarks()
      : EventMarks(
          night: (json['night'] as num?)?.toInt() ?? 0,
          dawn: (json['dawn'] as num?)?.toInt() ?? 0,
          lynch: (json['lynch'] as num?)?.toInt() ?? 0,
          end: json['end'] == true,
          tally: (json['tally'] as Map?)?.cast<String, Object?>(),
        );

  Map<String, Object?> toJson() => {
        'night': night,
        'dawn': dawn,
        'lynch': lynch,
        'end': end,
        if (tally != null) 'tally': tally,
      };
}

Map<String, Object?> _event(String kind, Map<String, Object?> data, {String? to}) =>
    {'to': to, 'kind': kind, 'data': data};

List<Map<String, Object?>> _list(Object? json) => [
      for (final row in (json as List<Object?>? ?? const [])) (row as Map).cast<String, Object?>(),
    ];

/// The names at the table, from the published seating.
String Function(String? seat) namesOf(Map<String, Object?> board) {
  final names = {
    for (final row in _list((board['seating'] as Map?)?['occupants'])) row['seat'] as String: row['name'] as String,
  };
  return (seat) => names[seat] ?? '?';
}

/// The final tally of a day vote, from the public board (votes are cast in
/// the open): who got how many (the revealed Mayor counts two) and how many
/// of the living did not vote for anyone.
Map<String, Object?> voteTally(Map<String, Object?> board) {
  final view = board['board'] as Map<String, Object?>;
  final name = namesOf(board);
  final mayor = view['mayor'] as String?;
  final counts = <String, int>{};
  var voted = 0;
  for (final vote in _list(view['dayVotes'])) {
    final target = vote['target'] as String?;
    if (target == null) continue;
    voted++;
    counts[target] = (counts[target] ?? 0) + (vote['seat'] == mayor ? 2 : 1);
  }
  final alive = (view['alive'] as List<Object?>? ?? const []).length;
  final order = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  return {
    'votes': [
      for (final seat in order) {'name': name(seat), 'count': counts[seat]},
    ],
    'abstained': alive - voted < 0 ? 0 : alive - voted,
  };
}

/// When a night closes, from each human seat's own view (choices made and
/// passes applied, before the night is resolved): the family's members are
/// told whom the family went for, a protector whom they covered.
List<Map<String, Object?>> nightClosing(Map<String, Map<String, Object?>> views, String Function(String? seat) name) {
  final events = <Map<String, Object?>>[];
  for (final MapEntry(key: seat, value: view) in views.entries) {
    if (view['alive'] != true) continue;
    if (view['team'] == 'mafia') {
      final counts = <String, int>{};
      for (final vote in _list(view['familyVotes'])) {
        final target = vote['target'] as String?;
        if (target != null) counts[target] = (counts[target] ?? 0) + 1;
      }
      if (counts.isNotEmpty) {
        final top = counts.values.reduce((a, b) => a > b ? a : b);
        final leaders = [for (final e in counts.entries) if (e.value == top) e.key];
        events.add(_event('familyTarget', {'name': leaders.length == 1 ? name(leaders.single) : null}, to: seat));
      }
    }
    final choice = (view['nightChoice'] as Map?)?.cast<String, Object?>();
    final kind = choice?['kind'] as String?;
    final target = choice?['target'] as String?;
    if (target != null && (kind == 'protect' || kind == 'guard' || kind == 'lend')) {
      events.add(_event('protected', {'name': name(target), 'kind': kind}, to: seat));
    }
  }
  return events;
}

String _key(Map<String, Object?> known) => '${known['seat']}|${known['team']}|${known['role']}';

/// The events of one step: what changed between the board and the seat
/// views published before it ([before] null and [beforeSeats] empty at the
/// deal) and those published now. [marks] is updated.
List<Map<String, Object?>> tableEvents({
  required Map<String, Object?>? before,
  required Map<String, Object?> after,
  required Map<String, Map<String, Object?>> beforeSeats,
  required Map<String, Map<String, Object?>> afterSeats,
  required EventMarks marks,
}) {
  final events = <Map<String, Object?>>[];
  final name = namesOf(after);
  final view = after['board'] as Map<String, Object?>;
  final stage = (after['schedule'] as Map?)?['stage'] as String?;
  final ended = stage == 'ended' || after['abandoned'] == true;

  // Dawn: once the death films are over.
  final dawn = (view['lastDawn'] as Map?)?.cast<String, Object?>();
  if (dawn != null && (dawn['round'] as int) > marks.dawn && stage != 'dawnFilms') {
    marks.dawn = dawn['round'] as int;
    final attacks = _list(dawn['attacks']);
    events.add(_event('dawn', {
      'round': dawn['round'],
      'dead': [for (final a in attacks) if (a['outcome'] == 'killed') name(a['target'] as String)],
      'saved': attacks.where((a) => a['outcome'] != 'killed').length,
      if (dawn['resurrected'] != null) 'resurrected': name(dawn['resurrected'] as String),
      if (dawn['heartbroken'] case final List<Object?> broken when broken.isNotEmpty)
        'heartbroken': [for (final seat in broken) name(seat as String)],
    }));
    final scoop = (dawn['scoop'] as Map?)?.cast<String, Object?>();
    if (scoop != null) {
      events.add(_event('scoop', {'name': name(scoop['seat'] as String), 'team': scoop['team'], 'role': scoop['role']}));
    }
    if (dawn['silenced'] case final String silenced) events.add(_event('silenced', {'name': name(silenced)}));
  }

  final mayor = view['mayor'] as String?;
  final mayorBefore = ((before?['board'] as Map?)?['mayor']) as String?;
  if (mayor != null && mayor != mayorBefore) events.add(_event('mayor', {'name': name(mayor)}));

  // The Pacifist's truce: who asked for it, and the exact role they showed.
  final pacifist = view['pacifist'] as String?;
  final pacified = view['pacified'] as String?;
  if (pacifist != null && pacified != null && pacifist != ((before?['board'] as Map?)?['pacifist'])) {
    final shown = _list(view['revealed']).where((k) => k['seat'] == pacified).firstOrNull;
    events.add(_event('truce', {'name': name(pacifist), 'target': name(pacified), 'role': shown?['role']}));
  }

  // The verdict: once the verdict film is over, with the tally of the vote.
  final lynch = (view['lastLynch'] as Map?)?.cast<String, Object?>();
  if (lynch != null && (lynch['round'] as int) > marks.lynch && stage != 'verdictFilm') {
    marks.lynch = lynch['round'] as int;
    final condemned = lynch['condemned'] as String?;
    events.add(_event('lynch', {
      'round': lynch['round'],
      'name': condemned == null ? null : name(condemned),
      'role': condemned == null ? null : lynch['role'],
      ...?marks.tally,
      if (lynch['bountyHunter'] case final String hunter) 'bountyHunter': name(hunter),
      if (lynch['heartbroken'] case final String broken) 'heartbroken': name(broken),
    }));
    marks.tally = null;
  }

  final gone = {...(before?['departed'] as List<Object?>? ?? const [])};
  for (final seat in (after['departed'] as List<Object?>? ?? const [])) {
    if (!gone.contains(seat)) events.add(_event('left', {'name': name(seat as String)}));
  }

  final round = view['round'] as int? ?? 0;
  if (stage == 'night' && round > marks.night) {
    marks.night = round;
    events.add(_event('night', {'round': round}));
  }

  if (ended && !marks.end) {
    marks.end = true;
    events.add(_event('end', {
      'winner': view['winner'],
      'abandoned': after['abandoned'] == true,
      'alone': [for (final seat in (view['personalWins'] as List<Object?>? ?? const [])) name(seat as String)],
    }));
  }
  if (ended) return events;

  // Only you: what your own view learned in this step.
  final fresh = before == null;
  final revealed = {for (final k in _list(view['revealed'])) k['seat']};
  for (final MapEntry(key: seat, value: now) in afterSeats.entries) {
    final then = beforeSeats[seat] ?? const <String, Object?>{};
    final bounty = now['bounty'] as String?;
    if (bounty != null && bounty != then['bounty']) events.add(_event('bounty', {'name': name(bounty)}, to: seat));
    if (fresh) continue;
    final mates = {...(now['teammates'] as List<Object?>? ?? const [])};
    final knew = {for (final k in _list(then['known'])) _key(k)};
    for (final known in _list(now['known'])) {
      final subject = known['seat'];
      if (subject == seat || mates.contains(subject) || revealed.contains(subject) || knew.contains(_key(known))) continue;
      events.add(_event('found', {'name': name(subject as String), 'team': known['team'], 'role': known['role']}, to: seat));
    }
    final cell = now['cell'] as String?;
    if (cell != null && cell != then['cell']) {
      events.add(_event('cell', {'name': name(cell), 'self': cell == seat}, to: seat));
    }
    if (now['busy'] == true && then['busy'] != true) events.add(_event('busy', const {}, to: seat));
    final lovers = [for (final s in (now['lovers'] as List<Object?>? ?? const [])) s as String];
    if (lovers.isNotEmpty && (then['lovers'] as List?)?.isNotEmpty != true) {
      events.add(_event('lovers', {'names': [for (final s in lovers) name(s)], 'self': lovers.contains(seat)}, to: seat));
    }
    final watched = _list(then['watches']).length;
    for (final watch in _list(now['watches']).skip(watched)) {
      events.add(_event('watch', {'name': name(watch['seat'] as String), 'visited': watch['visited'] == true}, to: seat));
    }
    final doused = [for (final s in (now['doused'] as List<Object?>? ?? const [])) s as String];
    final dousedBefore = {...(then['doused'] as List<Object?>? ?? const [])};
    if (doused.any((s) => !dousedBefore.contains(s))) {
      events.add(_event('doused', {'names': [for (final s in doused) name(s)]}, to: seat));
    }
  }
  return events;
}
