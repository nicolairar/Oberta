import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../online/app_update.dart';
import '../theme/app_theme.dart';

/// Apre il negozio fuori dall'app.
typedef OpenStore = Future<void> Function(Uri url);

Future<void> openStoreExternally(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Sopra tutta l'app: quando questa build è da aggiornare copre lo schermo
/// con «Aggiornamento obbligatorio» e il pulsante per il negozio. Non si
/// chiude. Ricontrolla ogni volta che l'app torna in primo piano.
class UpdateGateView extends StatefulWidget {
  final UpdateGate? gate;
  final OpenStore openStore;
  final Widget child;

  const UpdateGateView({super.key, required this.gate, required this.child, this.openStore = openStoreExternally});

  @override
  State<UpdateGateView> createState() => _UpdateGateViewState();
}

class _UpdateGateViewState extends State<UpdateGateView> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.gate?.check());
  }

  @override
  Widget build(BuildContext context) {
    final gate = widget.gate;
    if (gate == null) return widget.child;
    return ListenableBuilder(
      listenable: gate,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (gate.block case final block?)
            _UpdateCurtain(block: block, current: gate.version, openStore: widget.openStore),
        ],
      ),
    );
  }
}

class _UpdateCurtain extends StatelessWidget {
  final UpdateBlock block;
  final String current;
  final OpenStore openStore;

  const _UpdateCurtain({required this.block, required this.current, required this.openStore});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context).online;
    final reason = switch (block.reason) {
      UpdateReason.newerRelease => t.updateNewRelease(block.latestVersion ?? '?', current),
      UpdateReason.serverMinimum => t.updateServer,
    };
    // Niente «indietro»: il sipario resta finché non si aggiorna.
    return PopScope(
      canPop: false,
      child: Material(
        key: const ValueKey('update-required'),
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update, color: AppColors.gold, size: 48),
                    const SizedBox(height: 20),
                    Text(t.updateTitle, textAlign: TextAlign.center, style: AppText.display(26)),
                    const SizedBox(height: 14),
                    Text(reason, textAlign: TextAlign.center, style: AppText.body),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => unawaited(openStore(Uri.parse(block.url))),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                        child: Text(t.updateButton, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
