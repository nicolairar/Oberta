import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/screens/online/game/chat_mentions.dart';

void main() {
  test('il numero conta solo come parola a sé', () {
    for (final body in ['3', '#3', 'il 3', '3?', 'votate 3!', '(3)', 'io e 3, poi 5']) {
      expect(mentions(body, number: 3), isTrue, reason: body);
    }
    for (final body in ['13', '30', '#31', '1.234', 'nessuno', '']) {
      expect(mentions(body, number: 3), isFalse, reason: body);
    }
  });

  test('il nome, con o senza @, senza maiuscole e non dentro altre parole', () {
    expect(mentions('@anna sei tu?', name: 'anna'), isTrue);
    expect(mentions('secondo me Anna mente', name: 'anna'), isTrue);
    expect(mentions('anna.', name: 'anna'), isTrue);
    expect(mentions('annalisa mente', name: 'anna'), isFalse);
    expect(mentions('marianna mente', name: 'anna'), isFalse);
    expect(mentions('bot.alfa vota', name: 'bot.alfa'), isTrue);
  });

  test('i propri messaggi non si evidenziano', () {
    expect(mentions('sono il 3, anna', number: 3, name: 'anna', fromMe: true), isFalse);
  });

  test('niente numero né nome: niente', () {
    expect(mentions('3 anna'), isFalse);
  });
}
