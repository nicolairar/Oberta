import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/ui/widgets/death_scene.dart';

void main() {
  Duration ms(int value) => Duration(milliseconds: value);

  test('il film si rimette a tempo col nastro quando è un po\' avanti o indietro', () {
    expect(resyncTarget(heard: ms(407), film: ms(500)), ms(407));
    expect(resyncTarget(heard: ms(2600), film: ms(2300)), ms(2600));
  });

  test('qualche centesimo di scarto non vale un salto', () {
    expect(resyncTarget(heard: ms(2307), film: ms(2290)), isNull);
    expect(resyncTarget(heard: ms(1000), film: ms(1040)), isNull);
  });

  test('una posizione del nastro di prima non fa correre il film', () {
    // La seconda scena della notte: il lettore dice ancora 13 secondi.
    expect(resyncTarget(heard: ms(13000), film: ms(300)), isNull);
    expect(resyncTarget(heard: ms(0), film: ms(2400)), isNull);
  });

  test('oltre la fine del film non si salta', () {
    expect(resyncTarget(heard: DeathScene.length + ms(100), film: DeathScene.length - ms(200)), isNull);
  });
}
