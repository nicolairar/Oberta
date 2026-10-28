import 'dart:math';

import 'package:flutter/material.dart';

import '../../avatar/avatar_look.dart';
import '../../theme/app_theme.dart';
import '../player_avatar.dart';
import 'aura_backdrop.dart';
import 'seat_frame.dart';
import 'styled_name.dart';

/// Un posto del tavolo in miniatura, per la bottega: la carta ad arco come
/// la vedono gli altri in partita ([SeatCard]), con il ritratto di [look]
/// nella sua cornice e, sotto, la targhetta con il nome nel suo inchiostro.
class SeatPreview extends StatelessWidget {
  final AvatarLook look;
  final String name;

  const SeatPreview({super.key, required this.look, required this.name});

  /// L'altezza sul lato: la carta (1.32 della sua larghezza) e la targhetta
  /// che sporge di lato, tutta dentro il riquadro.
  static const aspect = 1.32 / 1.16;

  static const _brass = Color(0xFFD9B45A);
  static const _brassDeep = Color(0xFF8C6A26);
  static const _ink = Color(0xFF0C0907);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final outer = box.maxWidth.isFinite ? box.maxWidth : 120.0;
      // La carta è stretta quanto quella del tavolo: la targhetta sborda
      // dell'8% per parte.
      final width = outer / 1.16;
      final height = width * 1.32;
      final plate = max(14.0, width * 0.27);
      final arch = BorderRadius.vertical(top: Radius.circular(width / 2), bottom: Radius.circular(width * 0.12));
      return Center(
        child: SizedBox(
          width: outer,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: width * 0.08,
                width: width,
                top: 0,
                bottom: plate * 0.45,
                child: SeatFrame(
                  border: look.border,
                  radius: width / 2,
                  thickness: SeatFrame.thicknessFor(width),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: arch,
                      border: Border.all(color: _brassDeep, width: 1.4),
                      boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 5))],
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A2A1E), Color(0xFF120C08)]),
                    ),
                    child: ClipRRect(
                      borderRadius: arch,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AuraBackdrop(look: look, portrait: width * 0.86),
                          Align(
                            alignment: const Alignment(0, -0.1),
                            child: PlayerAvatar(seed: name, look: look, size: width * 0.86, bare: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: plate,
                child: Container(
                  key: const Key('seatPreview.plate'),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: plate * 0.28),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(plate / 2),
                    border: Border.all(color: _brass, width: 1.6),
                    boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: StyledName(
                      name,
                      text: name.toUpperCase(),
                      style: look.nameStyle,
                      base: AppText.display(plate * 0.64, color: AppColors.textPrimary).copyWith(letterSpacing: 0.6, height: 1.05),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
