import 'dart:math';

import 'package:flutter/material.dart';

import '../../online/online_models.dart';
import '../theme/app_theme.dart';

/// I loghi piccoli accanto a un nome: Steam per chi ha un account Steam
/// collegato, Apple per chi entra con Apple. Senza [steam]/[apple] li prende
/// da [PlayerMarks] per [name], e si ridisegna quando arrivano.
class PlatformBadges extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  /// Lo spazio prima del primo logo (dopo il nome).
  final double gap;

  final bool? steam;
  final bool? apple;

  const PlatformBadges(this.name, {super.key, this.size = 14, this.color, this.gap = 6, this.steam, this.apple});

  /// Loghi dati a mano (la classifica, il proprio profilo).
  const PlatformBadges.of({super.key, required bool this.steam, required bool this.apple, this.size = 14, this.color, this.gap = 6})
      : name = '';

  @override
  Widget build(BuildContext context) {
    if (steam != null && apple != null) return _row(steam!, apple!);
    return ValueListenableBuilder<int>(
      valueListenable: PlayerMarks.changes,
      builder: (context, _, _) {
        final mark = PlayerMarks.of(name);
        return _row(mark.steam, mark.apple);
      },
    );
  }

  Widget _row(bool onSteam, bool onApple) {
    if (!onSteam && !onApple) return const SizedBox.shrink();
    final ink = color ?? AppColors.textSecondary;
    return Padding(
      padding: EdgeInsets.only(left: gap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSteam) SteamLogo(key: const Key('mark.steam'), size: size, color: ink),
          if (onSteam && onApple) SizedBox(width: size * 0.35),
          if (onApple) Icon(Icons.apple, key: const Key('mark.apple'), size: size * 1.1, color: ink),
        ],
      ),
    );
  }
}

/// Il marchio di Steam, disegnato (niente immagini): il disco, la ruota
/// grande in alto a destra e la piccola in basso a sinistra, legate.
class SteamLogo extends StatelessWidget {
  final double size;
  final Color color;

  const SteamLogo({super.key, this.size = 14, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Steam',
        child: CustomPaint(size: Size.square(size), painter: _SteamPainter(color)),
      );
}

class _SteamPainter extends CustomPainter {
  final Color color;

  _SteamPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    // Il disegno si buca nel disco: BlendMode.clear dentro un layer.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(c, s / 2, Paint()..color = color);
    final hole = Paint()..blendMode = BlendMode.clear;
    final big = Offset(s * 0.64, s * 0.38);
    final small = Offset(s * 0.34, s * 0.66);
    canvas.drawCircle(big, s * 0.2, hole);
    canvas.drawCircle(big, s * 0.11, Paint()..color = color);
    canvas.drawCircle(small, s * 0.12, hole);
    canvas.drawCircle(small, s * 0.06, Paint()..color = color);
    final dir = (big - small) / (big - small).distance;
    final normal = Offset(-dir.dy, dir.dx) * (s * 0.055);
    final from = small + dir * (s * 0.1);
    final to = big - dir * (s * 0.19);
    canvas.drawPath(
      Path()
        ..moveTo((from + normal).dx, (from + normal).dy)
        ..lineTo((to + normal * 1.6).dx, (to + normal * 1.6).dy)
        ..lineTo((to - normal * 1.6).dx, (to - normal * 1.6).dy)
        ..lineTo((from - normal).dx, (from - normal).dy)
        ..close(),
      hole,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteamPainter old) => old.color != color;
}

/// L'immagine di Steam di un giocatore in un cerchio con la cornice d'oro,
/// al posto del ritratto disegnato. Mentre arriva, o se non arriva, si vede
/// [fallback] (il ritratto del gioco).
class SteamPicture extends StatelessWidget {
  final String url;
  final double size;
  final Widget fallback;
  final bool faded;

  const SteamPicture({super.key, required this.url, required this.size, required this.fallback, this.faded = false});

  static const _grey = ColorFilter.matrix([
    0.30, 0.55, 0.15, 0, 0, //
    0.30, 0.55, 0.15, 0, 0,
    0.30, 0.55, 0.15, 0, 0,
    0, 0, 0, 0.75, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    Widget image = ClipOval(
      child: Image.network(
        url,
        key: ValueKey(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * ratio).round().clamp(32, 512),
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) => frame == null && !sync ? fallback : child,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
    if (faded) image = ColorFiltered(colorFilter: _grey, child: image);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.9), width: max(1.5, size * 0.024)),
        ),
        child: image,
      ),
    );
  }
}

/// Il ritratto di un nome nelle liste (stanze, amici, ricerche): l'immagine
/// di Steam se il giocatore l'ha scelta, altrimenti [fallback].
class MarkedPortrait extends StatelessWidget {
  final String name;
  final double size;
  final Widget fallback;

  /// Un'immagine data a mano (il proprio profilo); senza, quella di [name].
  final String? picture;

  const MarkedPortrait({super.key, required this.name, required this.size, required this.fallback, this.picture});

  @override
  Widget build(BuildContext context) {
    if (picture != null) return SteamPicture(url: picture!, size: size, fallback: fallback);
    return ValueListenableBuilder<int>(
      valueListenable: PlayerMarks.changes,
      builder: (context, _, _) => switch (PlayerMarks.of(name).picture) {
        final url? => SteamPicture(url: url, size: size, fallback: fallback),
        null => fallback,
      },
    );
  }
}
