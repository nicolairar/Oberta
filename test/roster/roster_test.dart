import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/roster/roster.dart';
import 'package:oberta/rules/role_assignment.dart';

Roster rosterOf(Iterable<String> names) => names.fold(Roster.empty, (roster, name) => roster.add(name));

List<String> namesOf(Iterable<RosterMember> members) => [for (final member in members) member.name];

void main() {
  group('aggiungere', () {
    test('chi arriva si siede, con il nome ripulito e un identificativo suo', () {
      final roster = Roster.empty.add('  Marco ').add('Anna   Maria');

      expect(namesOf(roster.members), ['Marco', 'Anna Maria']);
      expect(roster.members.every((member) => member.seated), isTrue);
      expect(roster.members.every((member) => member.photo == null), isTrue);
      expect({for (final member in roster.members) member.id}, hasLength(2));
      expect(Roster.empty.isEmpty, isTrue, reason: 'l\'elenco di partenza non cambia mai');
    });

    test('un nome vuoto, troppo lungo o già preso non passa', () {
      final roster = rosterOf(['Marco']);

      expect(roster.checkName('   '), NameProblem.empty);
      expect(roster.checkName('x' * (maxNameLength + 1)), NameProblem.tooLong);
      expect(roster.checkName('x' * maxNameLength), isNull);
      expect(roster.checkName('marco'), NameProblem.taken);
      expect(roster.checkName(' MARCO  '), NameProblem.taken, reason: 'maiuscole e spazi non fanno un nome nuovo');
      expect(roster.checkName('Marco', exceptId: roster.members.single.id), isNull);
      expect(roster.checkName('Marta'), isNull);

      expect(() => roster.add('MARCO'), throwsA(isA<RosterError>()));
      expect(() => roster.add(''), throwsA(isA<RosterError>()));
    });

    test('la lunghezza si conta in lettere, anche quando una lettera pesa doppio', () {
      expect(Roster.empty.checkName('😀' * maxNameLength), isNull);
      expect(Roster.empty.checkName('😀' * (maxNameLength + 1)), NameProblem.tooLong);
    });

    test('l\'elenco ha un tetto', () {
      final roster = rosterOf([for (var i = 0; i < maxRosterSize; i++) 'Persona $i']);

      expect(roster.isFull, isTrue);
      expect(() => roster.add('Una di troppo'), throwsA(isA<RosterError>()));
    });
  });

  group('cambiare', () {
    test('rinominare cambia solo il nome, e rispetta i nomi degli altri', () {
      final roster = rosterOf(['Marco', 'Giulia']);
      final marco = roster.members.first;

      final renamed = roster.rename(marco.id, ' marco aurelio ');
      expect(namesOf(renamed.members), ['marco aurelio', 'Giulia']);
      expect(renamed.members.first.id, marco.id);

      expect(roster.rename(marco.id, 'MARCO').members.first.name, 'MARCO', reason: 'il proprio nome non è preso');
      expect(() => roster.rename(marco.id, 'giulia'), throwsA(isA<RosterError>()));
      expect(() => roster.rename(marco.id, ' '), throwsA(isA<RosterError>()));
    });

    test('la foto si mette, si sposta e si toglie', () {
      final roster = rosterOf(['Marco']);
      final id = roster.members.single.id;

      final shot = roster.withPhoto(id, 'a.jpg', x: 0.5, y: -3).members.single;
      expect(shot.photo, 'a.jpg');
      expect(shot.photoX, 0.5);
      expect(shot.photoY, -1, reason: 'l\'inquadratura non esce dalla foto');
      expect(roster.withPhoto(id, 'a.jpg').photos, {'a.jpg'});

      final bare = roster.withPhoto(id, 'a.jpg', x: 0.5, y: 0.5).withPhoto(id, null).members.single;
      expect(bare.photo, isNull);
      expect((bare.photoX, bare.photoY), (defaultPhotoX, defaultPhotoY));
    });

    test('togliere una persona non tocca le altre', () {
      final roster = rosterOf(['Marco', 'Giulia', 'Luca']);

      final without = roster.remove(roster.members[1].id);
      expect(namesOf(without.members), ['Marco', 'Luca']);
      expect(roster.remove('nessuno').members, hasLength(3));
    });

    test('via tutti: l\'elenco si svuota, gli identificativi non si riusano', () {
      final roster = rosterOf(['Marco', 'Giulia']);
      final old = {for (final member in roster.members) member.id};

      final cleared = roster.cleared();
      expect(cleared.isEmpty, isTrue);
      expect(old, isNot(contains(cleared.add('Luca').members.single.id)));
    });
  });

  group('il tavolo', () {
    test('ci si alza e ci si risiede senza uscire dall\'elenco', () {
      final roster = rosterOf(['Marco', 'Giulia', 'Luca']);
      final giulia = roster.members[1].id;

      final standing = roster.seat(giulia, false);
      expect(namesOf(standing.table), ['Marco', 'Luca']);
      expect(namesOf(standing.members), ['Marco', 'Giulia', 'Luca']);
      expect(namesOf(standing.seat(giulia, true).table), ['Marco', 'Giulia', 'Luca'], reason: 'al suo posto di prima');
      expect(identical(roster.seat(giulia, true), roster), isTrue, reason: 'era già seduta');
    });

    test('a tavolo pieno chi arriva resta a guardare, e nessuno si siede', () {
      var roster = rosterOf([for (var i = 0; i < maxTablePlayers; i++) 'Persona $i']);
      expect(roster.tableIsFull, isTrue);

      roster = roster.add('Ultimo');
      final last = roster.members.last;
      expect(last.seated, isFalse);
      expect(roster.table, hasLength(maxTablePlayers));
      expect(() => roster.seat(last.id, true), throwsA(isA<RosterError>()));

      roster = roster.seat(roster.members.first.id, false).seat(last.id, true);
      expect(roster.table, hasLength(maxTablePlayers));
      expect(roster.table.last.name, 'Ultimo');
    });

    test('il tavolo più piccolo e il più grande reggono un mazzo', () {
      expect(rolesForPlayerCount(minRolePlayers), hasLength(minRolePlayers));
      expect(rolesForPlayerCount(maxTablePlayers), hasLength(maxTablePlayers));
      expect(maxTablePlayers, greaterThan(minRolePlayers));
    });
  });

  group('salvare', () {
    test('l\'elenco torna uguale dopo essere passato dal testo', () {
      var roster = rosterOf(['Marco', 'Giulia', 'Luca']);
      roster = roster.withPhoto(roster.members[0].id, 'marco.jpg', x: 0.25, y: -0.5);
      roster = roster.seat(roster.members[2].id, false);

      final back = Roster.decode(roster.encode());

      expect(back.encode(), roster.encode());
      expect(namesOf(back.table), ['Marco', 'Giulia']);
      expect(back.members.first.photo, 'marco.jpg');
      expect((back.members.first.photoX, back.members.first.photoY), (0.25, -0.5));
      expect(back.members.last.seated, isFalse);
      expect(back.add('Sara').members.last.id, roster.add('Sara').members.last.id,
          reason: 'anche il contatore degli identificativi si salva');
    });

    test('nel testo salvato ci sono solo nomi, posti e foto', () {
      final json = jsonDecode(rosterOf(['Marco']).encode()) as Map<String, Object?>;

      expect(json.keys, unorderedEquals(['version', 'next', 'people']));
      expect((json['people'] as List).single, {'id': 'p1', 'name': 'Marco', 'seated': true});
    });

    test('un testo rovinato dà un elenco vuoto, non un errore', () {
      for (final broken in [null, '', 'non è json', '[]', '{"people": 7}', '{"people": [3, null, {"id": 1}]}']) {
        expect(Roster.decode(broken).isEmpty, isTrue, reason: '$broken');
      }
    });

    test('doppioni e gente di troppo si scartano rileggendo', () {
      final people = [
        {'id': 'p1', 'name': 'Marco', 'seated': true},
        {'id': 'p1', 'name': 'Sosia', 'seated': true},
        {'id': 'p2', 'name': 'MARCO', 'seated': true},
        {'id': 'p3', 'name': '   ', 'seated': true},
        for (var i = 0; i < maxTablePlayers; i++) {'id': 'p${10 + i}', 'name': 'Persona $i', 'seated': true},
      ];
      final roster = Roster.decode(jsonEncode({'version': 1, 'next': 2, 'people': people}));

      expect(roster.members, hasLength(1 + maxTablePlayers));
      expect(roster.table, hasLength(maxTablePlayers), reason: 'l\'ultimo non trova posto');
      expect(roster.members.last.seated, isFalse);
      final ids = {for (final member in roster.members) member.id};
      expect(ids, isNot(contains(roster.add('Nuovo').members.last.id)),
          reason: 'il contatore riparte da dopo l\'ultimo identificativo letto');
    });
  });
}
