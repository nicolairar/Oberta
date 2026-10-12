import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Schermo neutro tra un giocatore e l'altro quando il telefono è uno solo:
/// non mostra nulla di segreto finché chi lo riceve non dice che è pronto.
class HandoffView extends StatelessWidget {
  final String name;
  final VoidCallback onReady;

  const HandoffView({super.key, required this.name, required this.onReady});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.phone_iphone, color: AppColors.gold, size: 56),
        const SizedBox(height: 24),
        const Text('PASSA IL TELEFONO A', style: AppText.overline),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(name.toUpperCase(), style: AppText.display(40)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Nessun altro deve guardare lo schermo.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onReady, child: const Text('SONO IO')),
        ),
      ],
    );
  }
}
