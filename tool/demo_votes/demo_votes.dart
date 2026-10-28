// Vote visuals for the online table, before anything changes in the game.
// Three original 1940s ways to say "who votes whom" at a glance, drawn over
// the live SaloonTable and SeatCard (with their own vote marks switched off):
//
// 1 Scheda e gettoni: the voter's paper ballot pinned into the frame corner
//   ("→ 4", with the target's face on desk); the accused carries a wax seal
//   with the count and a row of brass tokens with the voters' numbers.
// 2 Ceralacca: every vote is a wax seal stamped with the voter's number,
//   pressed onto the accused's portrait; the voter wears a red silk ribbon
//   tag with the target's number.
// 3 Gesso: chalk on the frame. The voter has "→4" scrawled in the corner;
//   the accused a little slate with chalk tally marks and the voters' numbers.
//
// The focused seat (hover on desk, last tapped on phone; here: me, seat 2)
// is the only one whose vote is drawn as an arrow, so there's no spaghetti.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oberta/ui/screens/online/game/noir_ui.dart';
import 'package:oberta/ui/screens/online/game/saloon_table.dart';
import 'package:oberta/ui/screens/online/game/seat_card.dart';
import 'package:oberta/ui/theme/app_theme.dart';
import 'package:oberta/ui/widgets/player_avatar.dart';

import '../demo_chat/demo_chat.dart';

enum VoteLook { ballot, seals, chalk }

/// The seat in focus, and the seats around the table starting from me.
const focus = me;
final order = [for (var i = 0; i < seats.length; i++) seats[(me - 1 + i) % seats.length]];

/// Who votes this seat, and the weight (the revealed Mayor counts twice).
List<int> votersOf(int n) => [
  for (final d in seats)
    if (d.votesFor == n) d.n,
];
int weightOf(int voter) => seat(voter).shown?.name == 'sindaco' ? 2 : 1;
int votesOf(int n) => votersOf(n).fold(0, (sum, v) => sum + weightOf(v));

const _chalk = Color(0xFFEDEAE0);

TextStyle _chalkText(double size) => TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: const ['Courier', 'Roboto'],
  fontStyle: FontStyle.italic,
  fontWeight: FontWeight.w700,
  fontSize: size,
  height: 1,
  color: _chalk,
  shadows: const [
    Shadow(color: Color(0xAAFFFFFF), blurRadius: 1.5),
    Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1)),
  ],
);

/// One seat: the live card with no vote marks, then the look's marks.
Widget seatWith(VoteLook look, DemoSeat d, double width) {
  final plate = max(20.0, width * 0.27);
  final voters = votersOf(d.n);
  final votes = votesOf(d.n);
  final target = d.votesFor;
  final leading = d.n == 4;
  final card = SeatCard(
    name: d.name,
    number: d.n,
    width: width,
    fallen: d.dead,
    me: d.n == me,
    accused: leading,
    accusedLabel: 'In testa',
    selected: d.n == seat(me).votesFor,
    selectable: !d.dead && d.n != me,
    role: d.shown ?? (d.family ? null : null),
    onTap: () {},
  );
  final marks = <Widget>[];
  switch (look) {
    case VoteLook.ballot:
      if (target != null) {
        marks.add(
          Positioned(
            right: -width * 0.12,
            top: width * 0.04,
            child: _Ballot(target: target, size: max(11, width * 0.16), face: width >= 84),
          ),
        );
      }
      if (votes > 0) {
        marks.add(
          Positioned(
            left: -width * 0.4,
            right: -width * 0.4,
            bottom: plate * 0.92,
            child: Center(
              child: _TokenStack(votes: votes, voters: voters, size: max(15, width * 0.2)),
            ),
          ),
        );
      }
    case VoteLook.seals:
      if (target != null) {
        marks.add(
          Positioned(
            right: width * 0.04,
            top: -width * 0.06,
            child: _Ribbon(target: target, size: max(11, width * 0.15)),
          ),
        );
      }
      if (votes > 0) {
        marks.add(
          Positioned(
            left: -width * 0.4,
            right: -width * 0.4,
            bottom: plate * 0.85,
            child: Center(
              child: _SealCluster(voters: voters, votes: votes, size: max(17, width * 0.24)),
            ),
          ),
        );
      }
    case VoteLook.chalk:
      if (target != null) {
        marks.add(
          Positioned(
            right: -width * 0.14,
            top: width * 0.02,
            child: Transform.rotate(angle: -0.14, child: Text('→$target', style: _chalkText(max(14, width * 0.22)))),
          ),
        );
      }
      if (votes > 0) {
        marks.add(
          Positioned(
            left: -width * 0.4,
            right: -width * 0.4,
            bottom: plate * 0.9,
            child: Center(
              child: _Slate(votes: votes, voters: voters, size: max(12, width * 0.17)),
            ),
          ),
        );
      }
  }
  return Stack(clipBehavior: Clip.none, children: [card, ...marks]);
}

/// The ballot ("scheda"): a typed paper slip pinned into the frame corner.
class _Ballot extends StatelessWidget {
  final int target;
  final double size;
  final bool face;
  const _Ballot({required this.target, required this.size, this.face = false});

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.12,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(size * 0.3, size * 0.24, size * 0.3, size * 0.18),
          decoration: const BoxDecoration(
            color: Saloon.paper,
            border: Border(bottom: BorderSide(color: Saloon.blood, width: 2.5)),
            boxShadow: [BoxShadow(color: Colors.black, blurRadius: 5, offset: Offset(1, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '→$target',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: Saloon.paperInk,
                  fontSize: size * 1.1,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (face) ...[
                SizedBox(width: size * 0.25),
                ClipOval(
                  child: Container(
                    width: size * 1.3,
                    height: size * 1.3,
                    color: const Color(0xFFB89A6A),
                    child: PlayerAvatar(seed: seat(target).name, size: size * 1.3, bare: true),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: size * 0.1,
          top: -size * 0.14,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF2D58A), Saloon.brassDeep]),
              boxShadow: [BoxShadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _seal(String label, double size, {bool big = false}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const RadialGradient(center: Alignment(-0.3, -0.3), colors: [Color(0xFFE0343F), Color(0xFF7A0A12)]),
    border: Border.all(color: big ? const Color(0xFFF2D58A) : const Color(0xFF3A0508), width: big ? 2 : 1.4),
    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 5, offset: Offset(0, 2))],
  ),
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Text(label, style: AppText.display(size * 0.55, color: const Color(0xFFFFE3D6)).copyWith(letterSpacing: 0)),
    ),
  ),
);

Widget _token(String label, double size) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF2D58A), Saloon.brassDeep]),
    border: Border.all(color: const Color(0xFF1A120C)),
    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 1))],
  ),
  child: FittedBox(
    fit: BoxFit.scaleDown,
    child: Padding(
      padding: const EdgeInsets.all(1.5),
      child: Text(
        label,
        style: TextStyle(color: const Color(0xFF1A120C), fontSize: size * 0.62, fontWeight: FontWeight.w900, height: 1),
      ),
    ),
  ),
);

/// The wax seal with the count, then a brass token per voter.
class _TokenStack extends StatelessWidget {
  final int votes;
  final List<int> voters;
  final double size;
  const _TokenStack({required this.votes, required this.voters, required this.size});

  @override
  Widget build(BuildContext context) {
    final shown = voters.length > 4 ? voters.sublist(0, 3) : voters;
    final more = voters.length - shown.length;
    return Container(
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(color: Saloon.ink.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(size)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seal('$votes', size * 1.15, big: true),
          SizedBox(width: size * 0.12),
          // The tokens overlap like a stack of coins.
          SizedBox(
            width: size + size * 0.68 * (shown.length + (more > 0 ? 1 : 0) - 1),
            height: size,
            child: Stack(
              children: [
                for (final (i, n) in shown.indexed) Positioned(left: i * size * 0.68, child: _token('$n', size)),
                if (more > 0) Positioned(left: shown.length * size * 0.68, child: _token('+$more', size)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A red silk ribbon tag hanging from the frame, the target's number in gold.
class _Ribbon extends StatelessWidget {
  final int target;
  final double size;
  const _Ribbon({required this.target, required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RibbonPainter(),
    child: Container(
      width: size * 1.7,
      padding: EdgeInsets.only(top: size * 0.35, bottom: size * 0.75),
      alignment: Alignment.topCenter,
      child: Text('$target', style: AppText.display(size * 1.05, color: const Color(0xFFF2D58A)).copyWith(letterSpacing: 0, height: 1)),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.height * 0.22;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - notch)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF6E0A12), Color(0xFFB3202A), Color(0xFF6E0A12)]).createShader(Offset.zero & size),
    );
    canvas.drawLine(
      Offset(size.width * 0.14, 0),
      Offset(size.width * 0.14, size.height * 0.85),
      Paint()
        ..color = const Color(0x55F2D58A)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(size.width * 0.86, 0),
      Offset(size.width * 0.86, size.height * 0.85),
      Paint()
        ..color = const Color(0x55F2D58A)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wax seals pressed onto the portrait, one per voter, overlapping; the
/// Mayor's is bigger with ×2. The total sits on a dark tab under them.
class _SealCluster extends StatelessWidget {
  final List<int> voters;
  final int votes;
  final double size;
  const _SealCluster({required this.voters, required this.votes, required this.size});

  @override
  Widget build(BuildContext context) {
    final shown = voters.take(5).toList();
    final step = size * 0.62;
    final width = step * (shown.length - 1) + size * 1.2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: size * 1.2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * step,
                  top: (i.isEven ? 0 : size * 0.14) + (weightOf(shown[i]) > 1 ? 0 : size * 0.1),
                  child: Transform.rotate(
                    angle: (i - shown.length / 2) * 0.12,
                    child: _seal('${shown[i]}', weightOf(shown[i]) > 1 ? size * 1.2 : size, big: weightOf(shown[i]) > 1),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: size * 0.05),
          padding: EdgeInsets.symmetric(horizontal: size * 0.35, vertical: 1),
          decoration: BoxDecoration(color: Saloon.ink.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4)),
          child: Text(
            '$votes VOTI',
            style: TextStyle(color: const Color(0xFFFF8A80), fontSize: size * 0.48, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ],
    );
  }
}

/// A small school slate with chalk tally marks (five barred) and the voters.
class _Slate extends StatelessWidget {
  final int votes;
  final List<int> voters;
  final double size;
  const _Slate({required this.votes, required this.voters, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(size * 0.4, size * 0.25, size * 0.4, size * 0.2),
    decoration: BoxDecoration(
      color: const Color(0xFF26302B),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF6B4A2A), width: 2.5),
      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 5, offset: Offset(0, 2))],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size * (0.55 * min(votes, 5) + 0.3) + (votes > 5 ? size * 1.2 : 0), size * 1.1),
          painter: _TallyPainter(votes),
        ),
        SizedBox(height: size * 0.15),
        Text(voters.join(' '), style: _chalkText(size * 0.85)),
      ],
    ),
  );
}

class _TallyPainter extends CustomPainter {
  final int votes;
  _TallyPainter(this.votes);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _chalk
      ..strokeWidth = max(1.6, size.height * 0.11)
      ..strokeCap = StrokeCap.round;
    final step = size.height * 0.5;
    for (var g = 0; g * 5 < votes; g++) {
      final x0 = g * step * 6;
      final inGroup = min(5, votes - g * 5);
      for (var i = 0; i < min(4, inGroup); i++) {
        final x = x0 + step * 0.3 + i * step;
        canvas.drawLine(Offset(x + (i.isEven ? 0.6 : -0.4), 1), Offset(x - 0.5, size.height - 1), p);
      }
      if (inGroup == 5) {
        canvas.drawLine(Offset(x0, size.height * 0.75), Offset(x0 + step * 3.8, size.height * 0.25), p);
      }
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) => old.votes != votes;
}

/// The arrow for the focused seat only, in the look's material.
class _FocusArrow extends CustomPainter {
  final VoteLook look;
  final List<Offset> centers;
  final Size card;
  _FocusArrow(this.look, this.centers, this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final from = order.indexWhere((d) => d.n == focus);
    final to = order.indexWhere((d) => d.n == seat(focus).votesFor);
    if (from < 0 || to < 0) return;
    final a = centers[from];
    final b = centers[to];
    final mid = Offset.lerp(Offset.lerp(a, b, 0.5)!, size.center(Offset.zero), 0.35)!;
    final dirA = (mid - a) / (mid - a).distance;
    final dirB = (b - mid) / (b - mid).distance;
    final start = a + dirA * card.height * 0.66;
    final end = b - dirB * card.height * 0.5;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    final color = look == VoteLook.chalk ? _chalk : const Color(0xFFF2D58A);
    final w = max(3.0, card.width * 0.045);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (look == VoteLook.seals) {
      // A dashed brass thread.
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += w * 4) {
          canvas.drawPath(m.extractPath(d, min(d + w * 2.4, m.length)), line);
        }
      }
    } else {
      canvas.drawPath(path, line);
    }
    final tangent = path.computeMetrics().first.getTangentForOffset(path.computeMetrics().first.length)!;
    final dir = tangent.vector / tangent.vector.distance;
    final n = Offset(-dir.dy, dir.dx);
    final tip = tangent.position + dir * w * 1.5;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - dir.dx * w * 4 + n.dx * w * 2.6, tip.dy - dir.dy * w * 4 + n.dy * w * 2.6)
      ..lineTo(tip.dx - dir.dx * w * 4 - n.dx * w * 2.6, tip.dy - dir.dy * w * 4 - n.dy * w * 2.6)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// The table for one look. Look 1 uses the live pointing hand for the focus
/// (only the focused seat's); 2 and 3 draw their own arrow.
class VoteTable extends StatelessWidget {
  final VoteLook look;
  final double maxCard;
  const VoteTable({super.key, required this.look, this.maxCard = 118});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final width = SaloonTable.cardWidth(order.length, size, maxCard: maxCard);
      final centers = SaloonTable.seats(order.length, size, width);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SaloonTable(
              count: order.length,
              maxCard: maxCard,
              leading: order.indexWhere((d) => d.n == 4),
              hands: const [],
              seatBuilder: (context, i, w) => seatWith(look, order[i], w),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _FocusArrow(look, centers, Size(width, width * SaloonTable.cardAspect)))),
          ),
        ],
      );
    },
  );
}

/// The tally for the rail: "4 Dario ← 1, 2, 5, 8 (5)".
class VoteRail extends StatelessWidget {
  final double k;
  const VoteRail({super.key, this.k = 1});

  @override
  Widget build(BuildContext context) {
    final accused = [
      for (final d in seats)
        if (votesOf(d.n) > 0) d,
    ]..sort((a, b) => votesOf(b.n).compareTo(votesOf(a.n)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CHI VOTA CHI',
          style: TextStyle(color: Saloon.blood, fontSize: 13 * k, fontWeight: FontWeight.w900, letterSpacing: 2.4 * k),
        ),
        SizedBox(height: 10 * k),
        for (final d in accused)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5 * k),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SeatChip(d.n, size: 26 * k),
                SizedBox(width: 8 * k),
                Text(
                  d.name,
                  style: TextStyle(color: hueOf(d.n), fontSize: 18 * k, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 8 * k),
                Text(
                  '←',
                  style: TextStyle(fontFamily: 'Courier', color: AppColors.textSecondary, fontSize: 20 * k, fontWeight: FontWeight.w900),
                ),
                SizedBox(width: 6 * k),
                for (final v in votersOf(d.n))
                  Padding(
                    padding: EdgeInsets.only(right: 4 * k),
                    child: SeatChip(v, size: 20 * k),
                  ),
                const Spacer(),
                _seal('${votesOf(d.n)}', 30 * k),
              ],
            ),
          ),
        SizedBox(height: 8 * k),
        Text(
          'Il voto del Sindaco (5) vale doppio.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * k, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

/// The phone frame: HUD, table, roles, strip, the chat sheet peeking.
class PhoneVotes extends StatelessWidget {
  final VoteLook look;
  final String label;
  const PhoneVotes(this.look, this.label, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: felt(),
    child: Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Saloon.brass, borderRadius: BorderRadius.circular(6)),
            child: Text(
              label,
              style: const TextStyle(color: Saloon.ink, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 50, 0, 30),
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: DemoHud(k: 0.72)),
              const SizedBox(height: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: VoteTable(look: look),
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: DemoStrip(k: 0.74, status: 'Accusi 4 Dario.'),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                margin: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                decoration: BoxDecoration(
                  color: const Color(0xF20C0907),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(color: Saloon.brass.withValues(alpha: 0.8), width: 1.4),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Saloon.brassDeep, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(height: 6),
                    TabBarRow(tabs(family: false), ChatScale.phone),
                    const SizedBox(height: 4),
                    for (final e in dayLog.sublist(dayLog.length - 2)) entryWidget(e, ChatScale.phone, band: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A desk crop: the table at 1080p sizes with the tally rail beside it.
class DeskVotes extends StatelessWidget {
  final VoteLook look;
  const DeskVotes(this.look, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: felt(),
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: VoteTable(look: look, maxCard: 152)),
          const SizedBox(width: 28),
          SizedBox(
            width: 400,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(padding: const EdgeInsets.all(18), decoration: Saloon.scrim(radius: 16), child: const VoteRail()),
            ),
          ),
        ],
      ),
    ),
  );
}
