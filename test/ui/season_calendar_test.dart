import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/season/season.dart';

void main() {
  tearDown(() => SeasonLooks.debugOverride = null);

  test('Pasqua cade la domenica giusta', () {
    expect(SeasonCalendar.easter(2024), DateTime(2024, 3, 31));
    expect(SeasonCalendar.easter(2025), DateTime(2025, 4, 20));
    expect(SeasonCalendar.easter(2026), DateTime(2026, 4, 5));
    expect(SeasonCalendar.easter(2027), DateTime(2027, 3, 28));
    expect(SeasonCalendar.easter(2038), DateTime(2038, 4, 25));
  });

  test('il Natale va dal primo dicembre all\'Epifania, anche a cavallo dell\'anno', () {
    expect(SeasonCalendar.on(DateTime(2026, 11, 30)), isNot(Season.natale));
    expect(SeasonCalendar.on(DateTime(2026, 12, 1)), Season.natale);
    expect(SeasonCalendar.on(DateTime(2026, 12, 25, 23, 59)), Season.natale);
    expect(SeasonCalendar.on(DateTime(2027, 1, 6)), Season.natale);
    expect(SeasonCalendar.on(DateTime(2027, 1, 7)), isNull);
  });

  test('Halloween va dal 24 ottobre ai Morti', () {
    expect(SeasonCalendar.on(DateTime(2026, 10, 23)), isNull);
    expect(SeasonCalendar.on(DateTime(2026, 10, 24)), Season.halloween);
    expect(SeasonCalendar.on(DateTime(2026, 11, 2, 22)), Season.halloween);
    expect(SeasonCalendar.on(DateTime(2026, 11, 3)), isNull);
  });

  test('le feste mobili seguono Pasqua', () {
    // 2026: Pasqua il 5 aprile, martedì grasso il 17 febbraio.
    expect(SeasonCalendar.on(DateTime(2026, 2, 12)), Season.carnevale);
    expect(SeasonCalendar.on(DateTime(2026, 2, 17)), Season.carnevale);
    expect(SeasonCalendar.on(DateTime(2026, 2, 18)), isNull);
    expect(SeasonCalendar.on(DateTime(2026, 4, 2)), Season.pasqua);
    expect(SeasonCalendar.on(DateTime(2026, 4, 6)), Season.pasqua);
    expect(SeasonCalendar.on(DateTime(2026, 4, 7)), isNull);
  });

  test('per chi gioca non si accende niente finché nessuna prova è scelta', () {
    expect(SeasonLooks.picked, isEmpty);
    expect(SeasonLooks.at(DateTime(2026, 12, 24)), isNull);
    expect(SeasonLooks.at(DateTime(2026, 10, 31)), isNull);
    expect(SeasonLooks.today, isNull);
  });

  test('la prova si può forzare per provarla, qualunque sia il giorno', () {
    SeasonLooks.debugOverride = HalloweenLook.morti;
    expect(SeasonLooks.at(DateTime(2026, 7, 1)), HalloweenLook.morti);
    expect(SeasonLooks.today, HalloweenLook.morti);
    SeasonLooks.debugOverride = null;
    expect(SeasonLooks.today, isNull);
  });

  test('ogni prova ha un nome da scrivere in --dart-define=SEASON', () {
    expect(SeasonLooks.named('natale.cenone'), NataleLook.cenone);
    expect(SeasonLooks.named('halloween.nebbia'), HalloweenLook.nebbia);
    expect(SeasonLooks.named('halloween'), HalloweenLook.zucche);
    expect(SeasonLooks.named('ferragosto'), isNull);
    expect({for (final look in SeasonLooks.all) look.key}.length, SeasonLooks.all.length);
  });
}
