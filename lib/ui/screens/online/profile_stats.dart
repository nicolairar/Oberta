part of 'profile_sheet.dart';

/// Le linguette di carta in cima alla cartellina: «Scheda» e «Statistiche».
/// Quella aperta è dello stesso foglio che c'è sotto, l'altra resta indietro,
/// più scura.
class _IndexTabs extends StatelessWidget {
  final int page;
  final ValueChanged<int> onPage;
  final double scale;

  const _IndexTabs({required this.page, required this.onPage, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final w = StatsStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, label) in [(0, w.tabFile), (1, w.tabStats)])
          Padding(
            padding: EdgeInsets.only(left: 6 * scale),
            child: _IndexTab(
              key: Key(i == 0 ? 'profile.tab.file' : 'profile.tab.stats'),
              label: label,
              open: page == i,
              scale: scale,
              onTap: () => onPage(i),
            ),
          ),
      ],
    );
  }
}

class _IndexTab extends StatelessWidget {
  final String label;
  final bool open;
  final double scale;
  final VoidCallback onTap;

  const _IndexTab({super.key, required this.label, required this.open, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: open,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (open) return;
        HapticFeedback.selectionClick();
        onTap();
      },
      child: MouseRegion(
        cursor: open ? MouseCursor.defer : SystemMouseCursors.click,
        child: Container(
          height: (open ? 34 : 30) * scale,
          padding: EdgeInsets.symmetric(horizontal: 12 * scale),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open ? _paper : const Color(0xFFCDB98C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(5 * scale)),
            border: Border(
              top: BorderSide(color: _ink.withValues(alpha: open ? 0.35 : 0.25)),
              left: BorderSide(color: _ink.withValues(alpha: open ? 0.35 : 0.25)),
              right: BorderSide(color: _ink.withValues(alpha: open ? 0.35 : 0.25)),
            ),
            boxShadow: open ? null : const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, -1))],
          ),
          child: Text(
            label,
            style: _typed.copyWith(
              fontSize: 11.5 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2 * scale,
              color: _ink.withValues(alpha: open ? 0.95 : 0.6),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Il voltare pagina: il foglio nuovo arriva ruotando sulla piega, quello
/// vecchio sparisce sotto.
class _PageTurn extends StatelessWidget {
  final int page;
  final Widget child;

  const _PageTurn({required this.page, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
    transitionBuilder: (child, animation) {
      final incoming = child.key == ValueKey(page);
      return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = animation.value;
          return Opacity(
            opacity: incoming ? t.clamp(0.0, 1.0) : (t * 2 - 1).clamp(0.0, 1.0),
            child: Transform(
              alignment: page == 1 ? Alignment.centerLeft : Alignment.centerRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY((1 - t) * (page == 1 ? -0.5 : 0.5) * (incoming ? 1 : 0)),
              child: child,
            ),
          );
        },
      );
    },
    child: KeyedSubtree(key: ValueKey(page), child: child),
  );
}

/// Le statistiche lette dal server, con la casella delle partite di prova.
/// [k] ingrandisce tutto (desktop).
class _StatsView {
  final _DossierState host;
  final BuildContext context;
  final double k;

  _StatsView(this.host, this.context, {this.k = 1});

  StatsStrings get w => StatsStrings.of(context);
  AppStrings get strings => AppStrings.of(context);
  PlayerStats? get stats => host._stats;
  StatsSlice get s => stats!.slice(withTests: host._withTests);

  Widget header() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        w.title,
        style: _typed.copyWith(fontSize: 16 * k, fontWeight: FontWeight.w900, letterSpacing: 2.5 * k),
      ),
      Container(
        height: 2 * k,
        color: _ink,
        margin: EdgeInsets.only(top: 6 * k),
      ),
      Container(
        height: 0.8 * k,
        color: _ink,
        margin: EdgeInsets.only(top: 2 * k, bottom: 12 * k),
      ),
    ],
  );

  /// Caricamento, errore o nulla: un riquadro solo al posto dei numeri.
  Widget? placeholder() {
    if (host._statsFailed) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18 * k),
        child: Column(
          children: [
            Text(
              w.loadFailed,
              textAlign: TextAlign.center,
              style: _typed.copyWith(fontSize: 13 * k),
            ),
            SizedBox(height: 10 * k),
            TextButton(
              key: const Key('stats.retry'),
              onPressed: host._loadStats,
              child: Text(
                w.retry.toUpperCase(),
                style: _typed.copyWith(fontWeight: FontWeight.w900, fontSize: 13 * k),
              ),
            ),
          ],
        ),
      );
    }
    if (stats == null) {
      return Padding(
        padding: EdgeInsets.all(24 * k),
        child: Center(
          child: SizedBox.square(
            dimension: 22 * k,
            child: const CircularProgressIndicator(strokeWidth: 2.5, color: _ink),
          ),
        ),
      );
    }
    if (s.games == 0) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 14 * k),
        child: Text(
          w.empty,
          style: _typed.copyWith(fontStyle: FontStyle.italic, fontSize: 13 * k),
        ),
      );
    }
    return null;
  }

  /// La casella da spuntare, solo per chi ha giocato partite di prova.
  Widget toggle() {
    final tests = stats?.tests ?? 0;
    if (tests == 0) return const SizedBox.shrink();
    final on = host._withTests;
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * k),
      child: Semantics(
        checked: on,
        child: GestureDetector(
          key: const Key('stats.tests'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            host._toggleTests();
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Container(
                  width: 18 * k,
                  height: 18 * k,
                  decoration: BoxDecoration(
                    border: Border.all(color: _ink, width: 1.4 * k),
                  ),
                  child: on ? Icon(Icons.close, size: 16 * k, color: _stamp) : null,
                ),
                SizedBox(width: 8 * k),
                Flexible(
                  child: Text(
                    w.includeTestsCount(tests),
                    style: _typed.copyWith(fontSize: 13 * k, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// I quattro numeri grossi: partite, vinte, perse, percentuale.
  Widget bigNumbers() => _BigNumbers(
    keyPrefix: 'stats.big',
    k: k,
    items: [
      ('${s.games}', w.games, _ink),
      ('${s.wins}', w.wins, _won),
      ('${s.losses}', w.losses, _stamp),
      (w.percent(s.winRate), w.winRate, _ink),
    ],
  );

  Widget facts() {
    final favourite = Role.values.where((r) => r.name == s.favouriteRole).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(w.atTheTable, size: 13 * k),
        SizedBox(height: 6 * k),
        _FactLine(
          key: const Key('stats.time'),
          label: w.timePlayed,
          value: w.duration(s.seconds),
          note: s.timed < s.games ? w.timeMeasured(s.timed, s.games) : null,
          k: k,
        ),
        if (favourite != null)
          _FactLine(
            key: const Key('stats.favourite'),
            label: w.favouriteRole,
            value: strings.role(favourite).label,
            leading: RoleIcon(favourite, size: 22 * k),
            k: k,
          ),
        _FactLine(key: const Key('stats.streak'), label: w.longestStreak, value: '${s.longestStreak}', k: k),
        _FactLine(key: const Key('stats.survived'), label: w.survived, value: w.percent(s.survivedRate), k: k),
      ],
    );
  }

  Widget byTable() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(w.byTable, size: 13 * k),
      SizedBox(height: 4 * k),
      _GroupRow(key: const Key('stats.friends'), label: w.friends, group: s.friends, k: k),
      _GroupRow(key: const Key('stats.ranked'), label: w.ranked, group: s.ranked, k: k),
    ],
  );

  Widget byFaction() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(w.byFaction, size: 13 * k),
      SizedBox(height: 4 * k),
      for (final (team, label, color) in [
        ('mafia', w.family, _stamp),
        ('citizens', w.town, _won),
        ('neutral', w.alone, const Color(0xFF8A6A1E)),
      ])
        _GroupRow(
          key: Key('stats.team.$team'),
          label: label,
          group: s.teams[team] ?? GamesWins.none,
          color: color,
          k: k,
        ),
    ],
  );

  /// I ventun ruoli, dal più giocato; quelli mai toccati in fondo, sbiaditi.
  List<Widget> roleRows() {
    final roles = [...Role.values]
      ..sort((a, b) {
        final ga = s.roles[a.name] ?? GamesWins.none;
        final gb = s.roles[b.name] ?? GamesWins.none;
        final byGames = gb.games.compareTo(ga.games);
        if (byGames != 0) return byGames;
        final byWins = gb.wins.compareTo(ga.wins);
        return byWins != 0 ? byWins : a.index.compareTo(b.index);
      });
    return [
      for (final role in roles)
        _RoleRow(
          key: Key('stats.role.${role.name}'),
          role: role,
          name: strings.role(role).label,
          group: s.roles[role.name] ?? GamesWins.none,
          w: w,
          k: k,
        ),
    ];
  }

  static const featOrder = [
    'nights',
    'lynch_hits',
    'wins_alive',
    'saves',
    'finds',
    'snipes',
    'kills',
    'framed',
    'godfather_lynch',
  ];

  List<Widget> featTiles() => [
    for (final metric in featOrder)
      _Feat(key: Key('stats.feat.$metric'), label: w.counter(metric)!, value: stats?.counters[metric] ?? 0, k: k),
  ];

  Widget feats({int columns = 2}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(w.feats, size: 13 * k),
      SizedBox(height: 4 * k),
      Text(
        w.featsHint,
        style: _typed.copyWith(fontSize: 11 * k, color: _ink.withValues(alpha: 0.65)),
      ),
      SizedBox(height: 8 * k),
      LayoutBuilder(
        builder: (context, box) {
          final gap = 8 * k;
          final width = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final tile in featTiles()) SizedBox(width: width, child: tile)],
          );
        },
      ),
    ],
  );

  /// Abbandoni e assenze: li vede solo chi li ha fatti.
  Widget private() => Stack(
    clipBehavior: Clip.none,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(w.private, size: 13 * k),
          SizedBox(height: 4 * k),
          Text(
            w.privateHint,
            style: _typed.copyWith(fontSize: 11 * k, color: _ink.withValues(alpha: 0.65)),
          ),
          SizedBox(height: 6 * k),
          _FactLine(key: const Key('stats.abandoned'), label: w.abandoned, value: '${s.abandoned}', k: k),
          _FactLine(key: const Key('stats.afk'), label: w.afk, value: '${s.afk}', k: k),
        ],
      ),
      Positioned(
        right: 0,
        top: -8 * k,
        child: IgnorePointer(
          child: _Stamp(text: w.reserved, angle: -0.14, size: 12 * k),
        ),
      ),
    ],
  );
}

const _won = Color(0xFF2E5E2A);

/// Una riga del modulo: voce a sinistra, valore battuto a destra.
class _FactLine extends StatelessWidget {
  final String label;
  final String value;
  final String? note;
  final Widget? leading;
  final double k;

  const _FactLine({super.key, required this.label, required this.value, this.note, this.leading, this.k = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(vertical: 6 * k),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.15))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _typed.copyWith(fontSize: 13 * k)),
              if (note case final note?)
                Text(
                  note,
                  style: _typed.copyWith(fontSize: 10 * k, color: _ink.withValues(alpha: 0.55)),
                ),
            ],
          ),
        ),
        if (leading case final leading?) ...[leading, SizedBox(width: 6 * k)],
        Text(
          value,
          style: _typed.copyWith(fontSize: 15 * k, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

/// La percentuale di vittorie come una striscia d'inchiostro.
class _RateBar extends StatelessWidget {
  final double rate;
  final Color color;
  final double height;

  const _RateBar({required this.rate, required this.color, required this.height});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: 0.08),
      border: Border.all(color: _ink.withValues(alpha: 0.35), width: 0.8),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: rate.clamp(0.0, 1.0),
      child: ColoredBox(color: color.withValues(alpha: 0.75)),
    ),
  );
}

/// Un gruppo (tavolo o fazione): partite, vinte, percentuale e striscia.
class _GroupRow extends StatelessWidget {
  final String label;
  final GamesWins group;
  final Color color;
  final double k;

  const _GroupRow({super.key, required this.label, required this.group, this.color = _ink, this.k = 1});

  @override
  Widget build(BuildContext context) {
    final w = StatsStrings.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: _typed.copyWith(fontSize: 13.5 * k, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                w.gamesWins(group.games, group.wins),
                style: _typed.copyWith(fontSize: 11.5 * k, color: _ink.withValues(alpha: 0.75)),
              ),
              SizedBox(
                width: 48 * k,
                child: Text(
                  group.games == 0 ? '—' : w.percent(group.rate),
                  textAlign: TextAlign.right,
                  style: _typed.copyWith(fontSize: 14 * k, fontWeight: FontWeight.w900, color: color),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * k),
          _RateBar(rate: group.rate, color: color, height: 6 * k),
        ],
      ),
    );
  }
}

/// Un ruolo: il suo stemma, il nome, quante giocate e vinte.
class _RoleRow extends StatelessWidget {
  final Role role;
  final String name;
  final GamesWins group;
  final StatsStrings w;
  final double k;

  const _RoleRow({super.key, required this.role, required this.name, required this.group, required this.w, this.k = 1});

  @override
  Widget build(BuildContext context) {
    final played = group.games > 0;
    return Opacity(
      opacity: played ? 1 : 0.45,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4 * k),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _ink.withValues(alpha: 0.12))),
        ),
        child: Row(
          children: [
            RoleIcon(role, size: 28 * k),
            SizedBox(width: 10 * k),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _typed.copyWith(fontSize: 13.5 * k, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    played ? w.gamesWins(group.games, group.wins) : w.neverPlayed,
                    style: _typed.copyWith(fontSize: 10.5 * k, color: _ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            if (played) ...[
              SizedBox(
                width: 50 * k,
                child: _RateBar(rate: group.rate, color: _won, height: 6 * k),
              ),
              SizedBox(
                width: 44 * k,
                child: Text(
                  w.percent(group.rate),
                  textAlign: TextAlign.right,
                  style: _typed.copyWith(fontSize: 13 * k, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un contatore di sempre, in un riquadro a matita.
class _Feat extends StatelessWidget {
  final String label;
  final int value;
  final double k;

  const _Feat({super.key, required this.label, required this.value, this.k = 1});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8 * k, vertical: 6 * k),
    decoration: BoxDecoration(
      border: Border.all(color: _ink.withValues(alpha: 0.35), width: k),
      borderRadius: BorderRadius.circular(3 * k),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, maxLines: 2, style: _typed.copyWith(fontSize: 11 * k, height: 1.15)),
        ),
        SizedBox(width: 6 * k),
        Text(
          '$value',
          style: _typed.copyWith(fontSize: 17 * k, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

/// La pagina delle statistiche sul telefono: un foglio solo, da scorrere.
class _StatsPage extends StatelessWidget {
  final _DossierState host;

  const _StatsPage({required this.host});

  @override
  Widget build(BuildContext context) {
    final v = _StatsView(host, context);
    final placeholder = v.placeholder();
    return ListView(
      key: const Key('stats.page'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        v.header(),
        v.toggle(),
        if (placeholder != null)
          placeholder
        else ...[
          v.bigNumbers(),
          const SizedBox(height: 18),
          v.facts(),
          const SizedBox(height: 18),
          v.byTable(),
          const SizedBox(height: 14),
          v.byFaction(),
          const SizedBox(height: 18),
          _Heading(v.w.byRole),
          const SizedBox(height: 4),
          ...v.roleRows(),
          const SizedBox(height: 18),
          v.feats(),
          const SizedBox(height: 18),
          v.private(),
        ],
      ],
    );
  }
}

/// Sul desktop i due fogli della cartellina: a sinistra i conti, a destra
/// i ruoli e le imprese.
(Widget, Widget) _deskStatsSheets(_DossierState host, BuildContext context) {
  final v = _StatsView(host, context, k: 1.15);
  final placeholder = v.placeholder();
  final left = SingleChildScrollView(
    key: const Key('stats.page'),
    padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        v.header(),
        v.toggle(),
        if (placeholder != null)
          placeholder
        else ...[
          v.bigNumbers(),
          const SizedBox(height: 14),
          v.facts(),
          const SizedBox(height: 12),
          v.byTable(),
          const SizedBox(height: 8),
          v.byFaction(),
          const SizedBox(height: 14),
          v.private(),
        ],
      ],
    ),
  );
  if (placeholder != null) return (left, const SizedBox.shrink());
  final rows = _StatsView(host, context, k: 1.05).roleRows();
  final half = (rows.length + 1) ~/ 2;
  final right = SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(44, 34, 44, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(v.w.byRole, size: 15),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: rows.sublist(0, half))),
            const SizedBox(width: 36),
            Expanded(child: Column(children: rows.sublist(half))),
          ],
        ),
        const SizedBox(height: 20),
        _StatsView(host, context, k: 1.2).feats(columns: 3),
      ],
    ),
  );
  return (left, right);
}
