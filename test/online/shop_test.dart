import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/fake_online.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/ui/avatar/avatar_look.dart';

Matcher _fails(OnlineFailure failure) =>
    throwsA(isA<OnlineException>().having((error) => error.failure, 'failure', failure));

void main() {
  late FakeOnline online;
  late FakeShop shop;

  setUp(() {
    WornLooks.clear();
    online = FakeOnline()..signInReady(handle: 'anna');
    shop = online.shop;
  });

  group('comprare', () {
    test('servono abbastanza monete, e il prezzo è quello della classe', () async {
      await expectLater(shop.buy('hat.borsalino'), _fails(OnlineFailure.notEnoughCoins));
      online.award('me', coins: 1000);
      final after = await shop.buy('hat.borsalino');
      expect(after.coins, 300);
      expect((await online.profiles.me()).coins, 300);
      expect(await shop.owned(), {'hat.borsalino'});
      await expectLater(shop.buy('face.walrus'), _fails(OnlineFailure.notEnoughCoins));
      expect((await online.profiles.me()).coins, 300, reason: 'un acquisto fallito non costa niente');
    });

    test('non si compra due volte, né quello che è già di tutti', () async {
      online.award('me', coins: 5000);
      await shop.buy('outfit.trench_coat');
      await expectLater(shop.buy('outfit.trench_coat'), _fails(OnlineFailure.alreadyOwned));
      await expectLater(shop.buy('hat.fedora'), _fails(OnlineFailure.alreadyOwned));
      await expectLater(shop.buy('hat.sombrero'), _fails(OnlineFailure.itemNotFound));
      expect((await online.profiles.me()).coins, 5000 - 1800);
    });
  });

  group('indossare', () {
    test('solo quello che si possiede, o quello di base', () async {
      await expectLater(shop.equip('hat.topHat'), _fails(OnlineFailure.notOwned));
      final bowler = await shop.equip('hat.bowler');
      expect(bowler.avatar, {'hat': 'bowler'});
      online.award('me', coins: 700);
      await shop.buy('hat.topHat');
      final top = await shop.equip('hat.topHat');
      expect(top.look.hat.name, 'topHat');
      final bare = await shop.unequip('hat');
      expect(bare.avatar.containsKey('hat'), isFalse);
    });

    test('i baffi tengono la pelle salvata, o quella che l\'app mostra', () async {
      online.award('me', coins: 350);
      await shop.buy('face.walrus');
      var me = await shop.equip('face.walrus', tone: 'tan');
      expect(me.avatar['base'], 'tan_walrus');
      me = await shop.equip('face.mustache', tone: 'ebony');
      expect(me.avatar['base'], 'tan_mustache', reason: 'la pelle salvata vince');
      me = await shop.unequip('face');
      expect(me.avatar['base'], 'tan_clean');
      expect(me.look.base.tone, SkinTone.tan);
    });

    test('il look indossato si vede dove compare quel nome', () async {
      final fallback = AvatarLook.of('anna');
      online.award('me', coins: 700);
      await shop.buy('glasses.aviator');
      WornLooks.remember(await shop.equip('glasses.aviator'));
      expect(AvatarLook.of('anna').glasses.name, 'aviator');
      expect(AvatarLook.of('anna').hat, fallback.hat, reason: 'il resto resta quello del nome');
    });
  });

  group('il catalogo', () {
    test('ogni pezzo si sa disegnare, e la base è il look che si riceve dal nome', () {
      final look = AvatarLook.fallback('anna');
      for (final item in initialShopCatalog) {
        final slot = LookSlot.values.byName(item.slot);
        expect(look.wearing(slot, item.lookId), isNotNull, reason: item.id);
        expect(item.price, item.rarity.price);
      }
      for (final seed in ['anna', 'bruno', 'carla', 'dario', 'elena', 'franco', 'gina', 'zeno']) {
        final look = AvatarLook.fallback(seed);
        for (final slot in LookSlot.values) {
          final id = '${slot.name}.${look.idIn(slot)}';
          final item = initialShopCatalog.firstWhere((item) => item.id == id);
          expect(item.free, isTrue, reason: 'chi riceve $id dal nome non deve doverlo comprare');
        }
      }
      expect(initialShopCatalog.where((item) => !item.free).length, greaterThanOrEqualTo(25));
    });

    test('è lo stesso delle migrazioni', () {
      final sql = [
        'supabase/migrations/20261017221000_shop.sql',
        'supabase/migrations/20261018120000_shop_brands.sql',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final rows = RegExp(r"\('(\w+)\.(\w+)', '(\w+)', '(\w+)', '(\w+)', (\d+), .*?(?:, (null|'(\w+)'))?\)[,\n]")
          .allMatches(sql);
      final fromSql = {for (final m in rows) '${m[1]}.${m[2]}': '${m[4]} ${m[5]} ${m[6]} ${m[8]}'};
      final fromDart = {
        for (final item in initialShopCatalog)
          item.id: '${item.lookId} ${item.rarity.name} ${item.price} ${item.brand?.name}',
      };
      expect(fromSql, fromDart);
      expect(initialShopCatalog.map((item) => item.id).toSet().length, initialShopCatalog.length);
      for (final id in brandFeatured) {
        expect(sql, contains("('$id', "), reason: 'la vetrina delle case è anche nella migrazione');
      }
    });

    test('le case firmano i pezzi più cari', () {
      for (final brand in ShopBrand.values) {
        final pieces = initialShopCatalog.where((item) => item.brand == brand);
        expect(pieces, isNotEmpty, reason: brand.label);
        expect(pieces.every((item) => item.rarity.index >= ShopRarity.epico.index), isTrue, reason: brand.label);
      }
    });
  });
}
