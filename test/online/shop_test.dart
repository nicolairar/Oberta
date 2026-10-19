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
      await expectLater(shop.buy('hat.stetson'), _fails(OnlineFailure.itemNotFound));
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
        'supabase/migrations/20261018180000_shop_houses.sql',
        'supabase/migrations/20261018200000_shop_oddities.sql',
        'supabase/migrations/20261018220000_shop_absurd.sql',
        'supabase/migrations/20261020090000_barber_presentation.sql',
        'supabase/migrations/20261023090000_shop_calcio.sql',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final rows = RegExp(r"\('(\w+)\.(\w+)', '(\w+)', '(\w+)', '(\w+)', (\d+), .*?(?:, (null|'(\w+)'))?(?:, '(circo|carnevale|assurdo|calcio)')?\)[,\n]")
          .allMatches(sql);
      final fromSql = {for (final m in rows) '${m[1]}.${m[2]}': '${m[4]} ${m[5]} ${m[6]} ${m[8]} ${m[9]}'};
      final fromDart = {
        for (final item in initialShopCatalog)
          item.id: '${item.lookId} ${item.rarity.name} ${item.price} ${item.brand?.name} ${item.collection?.name}',
      };
      expect(fromSql, fromDart);
      expect(initialShopCatalog.map((item) => item.id).toSet().length, initialShopCatalog.length);
      for (final id in [...brandFeatured, ...odditiesFeatured]) {
        expect(sql, contains("('$id', "), reason: 'la vetrina delle case è anche nella migrazione');
      }
    });

    test('le stramberie: tutte in una collezione, il clown intero è leggendario', () {
      expect(odditiesDrop.length, greaterThanOrEqualTo(20));
      for (final item in odditiesDrop) {
        expect(item.collection, isNotNull, reason: item.id);
        expect(item.brand, isNull, reason: item.id);
      }
      for (final id in odditiesFeatured) {
        expect(initialShopCatalog.firstWhere((item) => item.id == id).rarity, ShopRarity.leggendario, reason: id);
      }
    });

    test("l'assurdo: almeno venticinque pezzi, i più grossi leggendari", () {
      final absurd = odditiesDrop.where((item) => item.collection == ShopCollection.assurdo).toList();
      expect(absurd.length, greaterThanOrEqualTo(25));
      expect(absurd.every((item) => item.rarity.index >= ShopRarity.raro.index), isTrue);
      expect(absurd.where((item) => item.rarity == ShopRarity.leggendario).length, greaterThanOrEqualTo(10));
      expect(absurd.map((item) => item.slot).toSet(), {'hat', 'face', 'glasses', 'outfit', 'accessory'});
    });

    test('le case firmano i pezzi più cari', () {
      for (final brand in ShopBrand.values) {
        final pieces = initialShopCatalog.where((item) => item.brand == brand);
        expect(pieces.length, inInclusiveRange(3, 6), reason: brand.label);
        expect(pieces.every((item) => item.rarity.index >= ShopRarity.epico.index), isTrue, reason: brand.label);
      }
    });
  });

  group('i pacchetti', () {
    final catalog = {for (final item in initialShopCatalog) item.id: item};

    test('sono gli stessi della migrazione, e ogni pezzo si vende anche da solo', () {
      final sql = [
        'supabase/migrations/20261022120000_shop_bundles.sql',
        'supabase/migrations/20261023090000_shop_calcio.sql',
      ].map((path) => File(path).readAsStringSync()).join('\n');
      final heads = {
        for (final m in RegExp(r"\('([a-z_]+)', '(set|premium)', (\d+), ").allMatches(sql)) m[1]!: '${m[2]} ${m[3]}',
      };
      final contents = <String, Set<String>>{};
      for (final m in RegExp(r"\('([a-z_]+)', '(\w+\.\w+)'\)").allMatches(sql)) {
        (contents[m[1]!] ??= {}).add(m[2]!);
      }
      expect(heads, {for (final b in initialShopBundles) b.id: '${b.tier} ${b.discountPct}'});
      expect(contents, {for (final b in initialShopBundles) b.id: b.itemIds.toSet()});
      for (final bundle in initialShopBundles) {
        for (final id in bundle.itemIds) {
          expect(catalog[id], isNotNull, reason: '${bundle.id}: $id');
          expect(catalog[id]!.free, isFalse, reason: '${bundle.id}: $id');
        }
      }
    });

    test('conviene: dal 30 al 45% sotto i pezzi presi uno a uno; il lusso è caro', () {
      for (final bundle in initialShopBundles) {
        final singles = bundle.singles(catalog, const {});
        final price = bundle.price(catalog, const {});
        expect(price * 100, lessThanOrEqualTo(singles * 70), reason: bundle.id);
        expect(price * 100, greaterThanOrEqualTo(singles * 54), reason: bundle.id);
        expect(price % 10, 0);
        if (bundle.id == 'curva') {
          expect(price, greaterThan(30000), reason: 'la curva intera è il pacchetto più caro');
        } else if (bundle.premium) {
          expect(price, inInclusiveRange(4000, 12000), reason: bundle.id);
        }
      }
    });

    test('il calcio: dieci squadre, quattro pezzi leggendari ciascuna, un pacchetto per squadra', () {
      expect(calcioDrop.length, 40);
      expect(calcioDrop.every((item) => item.rarity == ShopRarity.leggendario && item.collection == ShopCollection.calcio), isTrue);
      final look = AvatarLook.fallback('anna');
      for (final team in CalcioTeam.values) {
        for (final id in team.itemIds) {
          expect(CalcioTeam.of(id), team, reason: id);
          final item = catalog[id]!;
          expect(look.wearing(LookSlot.values.byName(item.slot), item.lookId), isNotNull, reason: id);
        }
        expect(initialShopBundles.where((b) => b.id == 'curva_${team.name}').single.itemIds, team.itemIds);
      }
      expect(initialShopBundles.firstWhere((b) => b.id == 'curva').itemIds.length, 40);
    });

    test('si paga solo quello che manca, sempre scontato', () async {
      online.award('me', coins: 700);
      await shop.buy('hat.trilby');
      online.award('me', coins: 1620);
      final after = await shop.buyBundle('detective');
      expect(after.coins, 0, reason: '(1800 + 350 + 350) meno il 35%, alla decina: 1620');
      expect(await shop.owned(), containsAll(['outfit.trench_coat', 'hat.trilby', 'face.pencil', 'accessory.pipe']));
      await expectLater(shop.buyBundle('detective'), _fails(OnlineFailure.alreadyOwned));
      await expectLater(shop.buyBundle('padrino'), _fails(OnlineFailure.notEnoughCoins));
      await expectLater(shop.buyBundle('nope'), _fails(OnlineFailure.itemNotFound));
    });
  });
}
