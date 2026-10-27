import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/handle_rules.dart';
import 'package:oberta/online/handle_suggestions.dart';
import 'package:oberta/online/online_models.dart';
import 'package:oberta/online/progress_models.dart';

void main() {
  group('il nome unico dal nome Steam', () {
    test('minuscolo, senza accenti né spazi, al massimo dodici', () {
      expect(HandleSuggestions.fromPersona('Don Vito Corleone'), 'donvitocorle');
      expect(HandleSuggestions.fromPersona('Nicolò'), 'nicolo');
      expect(HandleSuggestions.fromPersona('  xX_Sonny_Xx  '), 'xx_sonny_xx');
      expect(HandleSuggestions.fromPersona('__..Fredo..'), 'fredo');
      expect(HandleSuggestions.fromPersona('Tom-Hagen'), 'tom_hagen');
      expect(HandleSuggestions.fromPersona('Luca.Brasi.'), 'luca.brasi');
    });

    test('niente nome se non ne esce uno valido', () {
      expect(HandleSuggestions.fromPersona('☕☕☕'), isNull);
      expect(HandleSuggestions.fromPersona('Al'), isNull);
      expect(HandleSuggestions.fromPersona('Admin'), isNull);
      expect(HandleSuggestions.fromPersona('bot_alfa'), isNull);
    });

    test('le varianti hanno un numero in fondo e restano valide', () {
      final some = HandleSuggestions.variants('donvitocorle').take(12).toList();
      expect(some.first, 'donvitocorl1');
      expect(some[9], 'donvitocor10');
      expect(some.every(HandleRules.isValid), isTrue);
      expect(HandleSuggestions.variants('anna').first, 'anna1');
      expect(HandleSuggestions.variants('abcdefghij.k').first, 'abcdefghij1');
    });

    test('i nomi liberi si chiedono al server, poche volte', () async {
      final asked = <String>[];
      final free = await HandleSuggestions.freeVariants('anna', (name) async {
        asked.add(name);
        return name != 'anna1' && name != 'anna3';
      });
      expect(free, ['anna2', 'anna4', 'anna5']);
      expect(asked, hasLength(5));
      final none = await HandleSuggestions.freeVariants('anna', (_) async => false, maxAsks: 4);
      expect(none, isEmpty);
    });
  });

  group('i segni dei profili', () {
    setUp(PlayerMarks.clear);

    test('piattaforme e immagine di Steam arrivano col profilo', () {
      final profile = Profile.fromJson({
        'id': 'p1',
        'handle': 'vito',
        'avatar': <String, Object?>{},
        'on_steam': true,
        'on_apple': true,
        'picture_url': 'https://avatars.fastly.steamstatic.com/abc_full.jpg',
      });
      expect(profile.onSteam, isTrue);
      expect(
        PlayerMarks.of('vito'),
        const PlayerMark(steam: true, apple: true, picture: 'https://avatars.fastly.steamstatic.com/abc_full.jpg'),
      );
    });

    test('immagini non di Steam o non https non passano', () {
      for (final bad in [
        'http://avatars.steamstatic.com/a.jpg',
        'https://avatars.steamstatic.com.evil.com/a.jpg',
        'https://evil.com/a.jpg',
        'https://u@avatars.steamstatic.com/a.jpg',
        42,
      ]) {
        expect(Profile.safePicture(bad), isNull, reason: '$bad');
      }
      final profile = Profile.fromJson({'id': 'p2', 'handle': 'sonny', 'picture_url': 'https://evil.com/a.jpg'});
      expect(profile.pictureUrl, isNull);
      expect(PlayerMarks.of('sonny').isEmpty, isTrue);
    });

    test('il proprio profilo: la scelta dell\'immagine cambia quella pubblica', () {
      const me = Profile(id: 'me', handle: 'me', onSteam: true, steamAvatar: 'https://avatars.steamstatic.com/m.jpg');
      expect(me.copyWith(picture: ProfilePicture.steam).pictureUrl, 'https://avatars.steamstatic.com/m.jpg');
      expect(me.copyWith(picture: ProfilePicture.steam).copyWith(picture: ProfilePicture.game).pictureUrl, isNull);
      expect(me.copyWith(level: 3).pictureUrl, isNull);
    });

    test('la classifica porta le piattaforme', () {
      final board = Leaderboard.fromJson({
        'top': [
          {'rank': 1, 'handle': 'vito', 'tier': 'boss', 'steam': true, 'apple': false},
          {'rank': 2, 'handle': 'tom', 'tier': 'boss'},
        ],
      });
      expect(board.top.first.steam, isTrue);
      expect(board.top.last.steam, isFalse);
      expect(PlayerMarks.of('vito').steam, isTrue);
      expect(PlayerMarks.of('tom').isEmpty, isTrue);
    });
  });
}
