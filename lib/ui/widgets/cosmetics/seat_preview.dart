import 'package:flutter/material.dart';

import '../../avatar/avatar_look.dart';
import '../../theme/app_theme.dart';
import '../player_avatar.dart';
import 'seat_frame.dart';
import 'styled_name.dart';

/// Un posto del tavolo in miniatura, per la bottega: il ritratto di [look]
/// nella sua cornice e, sotto, la targhetta con il nome nel suo inchiostro.
/// Si prova qui quello che gli altri vedranno al tavolo.
class SeatPreview extends StatelessWidget {
  final AvatarLook look;
  final String name;

  const SeatPreview({super.key, required this.look, required this.name});

  static const aspect = 1.32;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth.isFinite ? box.maxWidth : 120.0;
        final height = width * aspect;
        final plate = width * 0.24;
        final frame = SeatFrame.thicknessFor(width);
        final radius = width * 0.12;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: frame * 0.6,
                  right: frame * 0.6,
                  top: frame * 0.6,
                  bottom: plate * 0.45,
                  child: SeatFrame(
                    border: look.border,
                    radius: radius,
                    thickness: frame,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: look.border == SeatBorder.none ? Border.all(color: const Color(0xFF8A6A2E), width: 1.4) : null,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF3A2A1E), Color(0xFF120C08)],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        child: Align(
                          alignment: const Alignment(0, -0.1),
                          child: PlayerAvatar(seed: name, look: look, size: width * 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -width * 0.04,
                  right: -width * 0.04,
                  bottom: 0,
                  height: plate,
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: plate * 0.3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15100C),
                      borderRadius: BorderRadius.circular(plate / 2),
                      border: Border.all(color: const Color(0xFFC9A227), width: 1.3),
                      boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: StyledName(
                        name,
                        text: name.toUpperCase(),
                        style: look.nameStyle,
                        base: AppText.display(plate * 0.56, color: AppColors.textPrimary).copyWith(letterSpacing: 0.8, height: 1.05),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
}
