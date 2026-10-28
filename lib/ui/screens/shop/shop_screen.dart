import 'dart:math';

import 'package:flutter/material.dart';

import '../../../l10n/app_language.dart';
import '../../../l10n/app_strings.dart';
import '../../../l10n/progress_strings.dart';
import '../../../l10n/shop_strings.dart';
import '../../../online/online_account.dart';
import '../../../online/online_services.dart';
import '../../avatar/avatar_look.dart';
import '../../avatar/look_painter.dart';
import '../../desktop/desktop_canvas.dart';
import '../../press.dart';
import '../../street/street_route.dart';
import '../../street/street_scaffold.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cosmetics/seat_preview.dart';
import '../../widgets/noir_modal.dart';
import '../../widgets/noir_notice.dart';
import '../../widgets/targa.dart';
import '../online/game/gesture_picker.dart' show GestureShowcase;
import '../online/game/table_gestures.dart' show GestureArt;
import '../online/missions_screen.dart';
import '../online/online_widgets.dart' show showFailure;
import 'shop_controller.dart';

export '../../../l10n/shop_strings.dart' show ShopDept, ShopOwnership;

part 'shop_desktop.dart';
part 'shop_parts.dart';
part 'shop_phone.dart';

/// Apre la bottega di chi è entrato.
Future<void> openShop(
  BuildContext context, {
  required OnlineAccount account,
  required ShopRepository shop,
  VoidCallback? onChangeFace,
}) =>
    StreetRoute.push<void>(
      context,
      StreetSection.shop,
      (context) => ShopScreen(
        account: account,
        shop: shop,
        onChangeFace: onChangeFace,
        progress: account.services.progress,
      ),
    );

/// I colori delle classi, come le etichette cucite dentro la giacca.
Color rarityColor(ShopRarity rarity) => switch (rarity) {
  ShopRarity.base => const Color(0xFF8A8178),
  ShopRarity.comune => const Color(0xFF7FA37A),
  ShopRarity.raro => const Color(0xFF5B95D6),
  ShopRarity.epico => const Color(0xFFAE6BDB),
  ShopRarity.leggendario => const Color(0xFFE8B84A),
};

const _cream = Color(0xFFF2E6CF);

/// Il nome della rotta del creatore di facce, se l'app ce l'ha.
const avatarRoute = '/avatar';

/// La bottega. Il giocatore grande nel mezzo, sotto la lampada; i reparti
/// sono medaglioni (la vetrina, poi un posto del corpo ciascuno). Sul
/// telefono i pezzi del reparto stanno sul bordo di una ruota d'ottone che
/// si gira col pollice: quello sotto la tacca lo si prova subito addosso, e
/// il cartellino sopra la ruota dice il prezzo e il bottone. Sul PC la
/// stessa bottega diventa il «manichino»: i reparti a sinistra, il busto
/// dietro il bancone, la vetrinetta dei pezzi a destra.
///
/// Monete, acquisti e guardaroba li decide il server ([ShopController]).
class ShopScreen extends StatefulWidget {
  final OnlineAccount account;
  final ShopRepository shop;

  /// Apre lo specchio del barbiere (le facce gratuite), se c'è.
  final VoidCallback? onChangeFace;

  /// Le missioni: il + del borsellino ci porta, perché le monete non si
  /// comprano, si guadagnano giocando. I pezzi chiusi aprono gli obiettivi.
  final ProgressRepository? progress;

  const ShopScreen({super.key, required this.account, required this.shop, this.onChangeFace, this.progress});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// Le sezioni della vetrina: i pezzi a tempo, i completi, il gran lusso.
enum _WindowSection { featured, sets, luxe }

class _ShopScreenState extends State<ShopScreen> {
  late final ShopController _shop = ShopController(shop: widget.shop, account: widget.account)..load();

  ProgressStrings get _progressStrings => ProgressStrings.of(context);

  /// Il + del borsellino: le missioni, dove si guadagnano le monete.
  VoidCallback? get _earnCoins =>
      widget.progress == null ? null : () => MissionsScreen.open(context, widget.progress!);

  ShopDept _dept = ShopDept.window;
  _WindowSection? _section;
  ShopFilter _filter = const ShopFilter();

  /// Il pezzo (o il pacchetto) scelto: la sua chiave, null per quello
  /// indossato o il primo dello scaffale.
  String? _pick;

  /// Dove sta la ruota: l'indice, con le frazioni mentre gira.
  double _turn = 0;

  /// The phone hero: the seat card (true), the bust (false), or whichever
  /// suits the picked piece (null: the card for frames and name inks).
  bool? _card;

  /// The desk's search field.
  final _search = TextEditingController();

  @override
  void dispose() {
    _shop.dispose();
    _search.dispose();
    super.dispose();
  }

  /// [setState] for the layout extensions.
  void _update(VoidCallback change) => setState(change);

  ShopStrings get _t => AppStrings.of(context).shop;
  AppLanguage get _language => AppStrings.of(context).language;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  void _say(String text) => showNotice(context, text, kind: NoticeKind.done);

  // --- What is on the shelf ---------------------------------------------

  List<_WindowSection> _sections(DateTime now) => [
    if (_shop.liveWindow(now).isNotEmpty) _WindowSection.featured,
    if (_shop.shelfBundles.any((b) => !b.premium)) _WindowSection.sets,
    if (_shop.shelfBundles.any((b) => b.premium)) _WindowSection.luxe,
  ];

  _WindowSection? _openSection(DateTime now) {
    final sections = _sections(now);
    if (sections.isEmpty) return null;
    return sections.contains(_section) ? _section : sections.first;
  }

  /// Tutto lo scaffale del reparto, prima dei filtri.
  List<ShopItem> _deptAll() => _shop.deptItems(_dept);

  /// Quello che si vede adesso, nell'ordine della ruota.
  List<_Entry> _entries(DateTime now) {
    if (_dept == ShopDept.window) {
      return switch (_openSection(now)) {
        _WindowSection.featured => [for (final (item, feature) in _shop.liveWindow(now)) _Entry.item(item, feature: feature)],
        _WindowSection.sets => [
          for (final b in _shop.shelfBundles)
            if (!b.premium) _Entry.bundle(b),
        ],
        _WindowSection.luxe => [
          for (final b in _shop.shelfBundles)
            if (b.premium) _Entry.bundle(b),
        ],
        null => const [],
      };
    }
    // The pieces for sale and bought first, the house's own at the end.
    final items = _shop.filtered(_deptAll(), _filter, _language);
    return [
      for (final free in [false, true])
        for (final item in items)
          if (item.free == free) _Entry.item(item),
    ];
  }

  /// La voce scelta: quella toccata, se c'è ancora, o quella indossata.
  int _pickedIndex(List<_Entry> entries) {
    if (entries.isEmpty) return -1;
    final i = entries.indexWhere((e) => e.key == _pick);
    if (i >= 0) return i;
    final worn = entries.indexWhere((e) => e.item != null && _shop.stateOf(e.item!) == ItemState.worn && !e.item!.free);
    return max(0, worn);
  }

  void _openDept(ShopDept dept) => setState(() {
    _search.clear();
    _dept = dept;
    _card = null;
    _filter = const ShopFilter();
    _pick = null;
    _turn = -1;
  });

  void _openSectionTap(_WindowSection section) => setState(() {
    _section = section;
    _pick = null;
    _turn = -1;
  });

  void _setFilter(ShopFilter filter) => setState(() {
    _filter = filter;
    _pick = null;
    _turn = -1;
  });

  void _choose(_Entry entry, {double? turn}) => setState(() {
    _pick = entry.key;
    if (turn != null) _turn = turn;
  });

  /// Il look addosso al busto per [entry].
  AvatarLook _lookOf(_Entry? entry) {
    if (entry == null) return _shop.look;
    if (entry.bundle case final bundle?) return _shop.bundleLook(bundle);
    return _shop.tryOn(entry.item!);
  }

  // --- Buying and wearing -------------------------------------------------

  Future<void> _buy(ShopItem item) async {
    final t = _t;
    final language = _language;
    if (_shop.coins < item.price) {
      showNotice(context, t.missing(item.price - _shop.coins), kind: NoticeKind.error);
      return;
    }
    final yes = await showNoirDialog<bool>(
      context,
      builder: (context) => _ReceiptDialog(item: item, coins: _shop.coins, strings: t, language: language),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await _shop.buy(item);
      if (mounted) _say(t.bought(item.name(language)));
    });
  }

  Future<void> _buyBundle(ShopBundle bundle) async {
    final t = _t;
    final language = _language;
    final price = _shop.bundlePrice(bundle);
    if (_shop.coins < price) {
      showNotice(context, t.missing(price - _shop.coins), kind: NoticeKind.error);
      return;
    }
    final yes = await showNoirDialog<bool>(
      context,
      builder: (context) => _BundleReceipt(
        bundle: bundle,
        price: price,
        saved: _shop.bundleSingles(bundle) - price,
        coins: _shop.coins,
        strings: t,
        language: language,
      ),
    );
    if (yes != true || !mounted) return;
    await _run(() async {
      await _shop.buyBundle(bundle);
      if (mounted) _say(t.bundleBought(bundle.name(language)));
    });
  }

  /// Il bottone del cartellino: compra, indossa, togli, o niente da fare.
  Widget _action(_Entry entry, {double? height, bool desk = false, bool expand = false, bool short = false}) {
    final t = _t;
    if (entry.bundle case final bundle?) {
      final complete = _shop.bundleComplete(bundle);
      return TargaButton(
        key: const Key('shop.bundle.buy'),
        label: complete ? t.complete : (short ? t.buy : t.buyBundle),
        price: complete ? null : _shop.bundlePrice(bundle),
        height: height,
        desk: desk,
        expand: expand,
        feel: Press.chips,
        onPressed: complete || _shop.busy ? null : () => _buyBundle(bundle),
      );
    }
    final item = entry.item!;
    final (label, kind, action, price) = switch (_shop.stateOf(item)) {
      ItemState.forSale => (t.buy, TargaKind.primary, () => _buy(item), item.price),
      ItemState.locked => (
          _progressStrings.unlocksWith(_progressStrings.mission(item.unlock!)),
          TargaKind.secondary,
          widget.progress == null ? null : () => MissionsScreen.open(context, widget.progress!, tab: 2),
          null,
        ),
      ItemState.owned when item.isGesture => (t.owned, TargaKind.secondary, null, null),
      ItemState.owned => (t.wear, TargaKind.primary, () => _run(() => _shop.equip(item)), null),
      ItemState.worn => item.free
          ? (t.worn, TargaKind.secondary, null, null)
          : (t.takeOff, TargaKind.secondary, () => _run(() => _shop.takeOff(item)), null),
    };
    return TargaButton(
      key: const Key('shop.action'),
      label: label,
      kind: kind,
      price: price,
      height: height,
      desk: desk,
      expand: expand,
      feel: price != null ? Press.chips : Press.tap,
      onPressed: _shop.busy || action == null ? null : action,
    );
  }

  // --- Filters ------------------------------------------------------------

  Future<void> _openFilters() => showNoirSheet<void>(
    context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) {
        void set(ShopFilter f) {
          _setFilter(f);
          setSheet(() {});
        }

        return _FilterSheet(
          strings: _t,
          language: _language,
          filter: _filter,
          collections: ShopController.collectionsIn(_deptAll()),
          onChanged: set,
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _shop,
    builder: (context, _) {
      final desk = DesktopCanvas.of(context);
      if (_shop.loading || _shop.error != null) return _waiting(desk);
      return desk ? _desktop() : _phone();
    },
  );

  Widget _waiting(bool desk) => Scaffold(
    backgroundColor: const Color(0xFF07070B),
    body: StreetBackdrop(
      section: StreetSection.shop,
      desk: desk,
      title: _t.title,
      builder: (context, layout) => Stack(
        children: [
          Positioned(left: desk ? 28 : 8, top: layout.neon.center.dy - 23, child: const TargaBackButton(key: Key('shop.back'), size: 46)),
          Center(
            child: switch (_shop.error) {
              null => const CircularProgressIndicator(color: AppColors.gold),
              final error => TargaButton(
                label: '${AppStrings.of(context).online.failure(error is OnlineException ? error.failure : OnlineFailure.unknown)} ↻',
                kind: TargaKind.secondary,
                onPressed: _shop.load,
              ),
            },
          ),
        ],
      ),
    ),
  );
}
