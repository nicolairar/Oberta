part of 'profile_sheet.dart';

/// Il fascicolo pubblico di un altro giocatore, da un posto al tavolo, un
/// messaggio, gli amici o la classifica: ritratto, nome, livello, grado,
/// titolo, le tre medaglie più rare e i numeri delle partite vere. Solo
/// l'account: niente della partita in corso, niente abbandoni né condotta.
Future<void> showPublicProfile(BuildContext context, {required OnlineServices services, required String target}) {
  HapticFeedback.selectionClick();
  final load = services.profiles.publicProfile(target);
  if (DesktopCanvas.peek(context)) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: const Color(0xCC050404),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
      pageBuilder: (context, _, _) => DeskTheme(
        child: DeskEscape(
          onEscape: () => Navigator.of(context).maybePop(),
          child: Center(
            child: SizedBox(
              width: _DeskDossier.width,
              height: _DeskDossier.height,
              child: Material(type: MaterialType.transparency, child: _PublicDossier(load: load, desk: true)),
            ),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(heightFactor: 0.94, child: _PublicDossier(load: load)),
  );
}

class _PublicDossier extends StatelessWidget {
  final Future<PublicProfile> load;
  final bool desk;

  const _PublicDossier({required this.load, this.desk = false});

  Widget _folder(Widget left, [Widget? right, String? tab]) => desk
      ? _DeskFolder(left: left, right: right ?? const SizedBox.shrink(), tab: tab)
      : _Folder(tab: tab, child: left);

  @override
  Widget build(BuildContext context) => FutureBuilder<PublicProfile>(
    future: load,
    builder: (context, snap) {
      if (snap.hasError) {
        return _folder(
          Center(
            key: const Key('public.unavailable'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                StatsStrings.of(context).unavailable,
                textAlign: TextAlign.center,
                style: _typed.copyWith(fontSize: desk ? 20 : 14, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        );
      }
      final p = snap.data;
      if (p == null) return _folder(const Center(child: CircularProgressIndicator(color: _ink)));
      final id = p.profile.id;
      final tab = 'N. ${(id.length >= 6 ? id.substring(0, 6) : id).toUpperCase()}';
      final k = desk ? 1.15 : 1.0;
      final view = _PublicView(p, context, k: k);
      if (!desk) {
        return _folder(
          ListView(
            key: const Key('public.page'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              view.header(),
              view.identity(photo: 116),
              const SizedBox(height: 20),
              if (!p.open)
                view.closed()
              else ...[
                view.numbers(),
                const SizedBox(height: 18),
                view.facts(),
                const SizedBox(height: 18),
                view.medals(),
                const SizedBox(height: 18),
                view.roles(),
              ],
            ],
          ),
          null,
          tab,
        );
      }
      final left = SingleChildScrollView(
        key: const Key('public.page'),
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            view.header(),
            view.identity(photo: 260),
            const SizedBox(height: 28),
            if (p.open) view.medals() else view.closed(),
          ],
        ),
      );
      final right = !p.open
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(44, 34, 44, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  view.numbers(),
                  const SizedBox(height: 20),
                  view.facts(),
                  const SizedBox(height: 20),
                  view.roles(),
                ],
              ),
            );
      return _folder(left, right, tab);
    },
  );
}

class _PublicView {
  final PublicProfile p;
  final BuildContext context;
  final double k;

  _PublicView(this.p, this.context, {this.k = 1});

  StatsStrings get w => StatsStrings.of(context);

  Widget header() => Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            w.publicTitle,
            style: _typed.copyWith(fontSize: 16 * k, fontWeight: FontWeight.w900, letterSpacing: 2.5 * k),
          ),
          Container(height: 2 * k, color: _ink, margin: EdgeInsets.only(top: 6 * k)),
          Container(height: 0.8 * k, color: _ink, margin: EdgeInsets.only(top: 2 * k, bottom: 18 * k)),
        ],
      ),
      Positioned(
        right: 0,
        top: -8 * k,
        child: IgnorePointer(
          child: _Stamp(text: p.open ? w.onRecord : w.reserved, angle: 0.12, size: 12 * k),
        ),
      ),
    ],
  );

  Widget identity({required double photo}) {
    final t = AppStrings.of(context).online;
    final profile = p.profile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Mugshot(profile: profile, width: photo),
        SizedBox(width: 16 * k),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(t.dossierName, size: 10.5 * k),
              _TypedLine(text: profile.name, size: 20 * k, steam: profile.onSteam, apple: profile.onApple),
              if (p.title case final title?)
                Padding(
                  key: const Key('public.title'),
                  padding: EdgeInsets.only(top: 4 * k),
                  child: Text(
                    '«${ProgressStrings.of(context).titleName(title)}»',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _typed.copyWith(fontSize: 13 * k, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700),
                  ),
                ),
              SizedBox(height: 14 * k),
              _Field(t.dossierRank, size: 10.5 * k),
              SizedBox(height: 4 * k),
              Row(
                children: [
                  _LevelSeal(
                    key: const Key('public.level'),
                    level: profile.level,
                    label: t.levelShort(profile.level),
                    size: 56 * k,
                  ),
                  SizedBox(width: 10 * k),
                  if (p.tier case final tier?)
                    Flexible(
                      child: _Stamp(
                        text: t.tierName(tier).toUpperCase(),
                        angle: -0.06,
                        color: _ink,
                        size: 13 * k,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget closed() => Padding(
    key: const Key('public.closed'),
    padding: EdgeInsets.symmetric(vertical: 12 * k),
    child: Text(
      w.closedFile,
      style: _typed.copyWith(fontSize: 13.5 * k, fontStyle: FontStyle.italic),
    ),
  );

  Widget numbers() => _BigNumbers(
    keyPrefix: 'public.big',
    k: k,
    items: [
      ('${p.games}', w.games, _ink),
      ('${p.wins}', w.wins, _won),
      (w.percent(p.winRate), w.winRate, _ink),
    ],
  );

  Widget facts() {
    final strings = AppStrings.of(context);
    final favourite = Role.values.where((r) => r.name == p.favouriteRole).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(w.atTheTable, size: 13 * k),
        SizedBox(height: 6 * k),
        _FactLine(key: const Key('public.time'), label: w.timePlayed, value: w.duration(p.seconds), k: k),
        if (favourite != null)
          _FactLine(
            key: const Key('public.favourite'),
            label: w.favouriteRole,
            value: strings.role(favourite).label,
            leading: RoleIcon(favourite, size: 22 * k),
            k: k,
          ),
        _FactLine(key: const Key('public.streak'), label: w.longestStreak, value: '${p.longestStreak}', k: k),
      ],
    );
  }

  Widget medals() {
    final s = ProgressStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(w.featured, size: 13 * k),
        SizedBox(height: 8 * k),
        if (p.featured.isEmpty)
          Text(w.noMedals, style: _typed.copyWith(fontStyle: FontStyle.italic, fontSize: 13 * k))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in p.featured)
                Expanded(
                  child: Column(
                    key: Key('public.medal.$id'),
                    children: [
                      _MedalDisc(tier: Achievement.byId(id)?.tier ?? 1, size: 48 * k),
                      SizedBox(height: 6 * k),
                      Text(
                        s.achievement(id).$1,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _typed.copyWith(fontSize: 11.5 * k, fontWeight: FontWeight.w800, height: 1.15),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget roles() {
    final strings = AppStrings.of(context);
    final rows = [
      for (final r in p.roles)
        if (Role.values.where((role) => role.name == r.role).firstOrNull case final role?)
          _RoleRow(
            key: Key('public.role.${role.name}'),
            role: role,
            name: strings.role(role).label,
            group: GamesWins(r.games, r.wins),
            w: w,
            k: k,
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(w.topRoles, size: 13 * k),
        SizedBox(height: 4 * k),
        if (rows.isEmpty)
          Text(w.empty, style: _typed.copyWith(fontStyle: FontStyle.italic, fontSize: 13 * k))
        else
          ...rows,
      ],
    );
  }
}

/// Una medaglia coniata: bronzo, argento, oro.
class _MedalDisc extends StatelessWidget {
  final int tier;
  final double size;

  const _MedalDisc({required this.tier, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = switch (tier) {
      1 => const [Color(0xFFD08A4E), Color(0xFF7A4520)],
      2 => const [Color(0xFFE2E2E2), Color(0xFF7C7C80)],
      _ => const [Color(0xFFF3D27A), Color(0xFF9C7420)],
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
        border: Border.all(color: colors.last, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Icon(Icons.military_tech, color: const Color(0xFF2A1C14), size: size * 0.6),
    );
  }
}

/// I numeri grossi in riquadri a inchiostro.
class _BigNumbers extends StatelessWidget {
  final List<(String, String, Color)> items;
  final String keyPrefix;
  final double k;

  const _BigNumbers({required this.items, required this.keyPrefix, this.k = 1});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, (value, label, color)) in items.indexed) ...[
        if (i > 0) SizedBox(width: 8 * k),
        Expanded(
          child: Container(
            key: Key('$keyPrefix.$i'),
            padding: EdgeInsets.symmetric(vertical: 8 * k, horizontal: 4 * k),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.7), width: 1.6 * k),
              borderRadius: BorderRadius.circular(3 * k),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: _typed.copyWith(fontSize: 26 * k, fontWeight: FontWeight.w900, color: color, height: 1.1),
                  ),
                ),
                SizedBox(height: 2 * k),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 10 * k,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2 * k,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}
