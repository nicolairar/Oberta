import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../l10n/desktop_strings.dart';
import '../../settings/display_settings.dart';
import '../desktop/desktop_canvas.dart';
import '../desktop/desktop_platform.dart';
import 'online/link_account_sheet.dart';
import '../widgets/content_width.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/safety_strings.dart';
import '../../l10n/stats_strings.dart';
import '../../l10n/settings_strings.dart';
import '../../online/online_services.dart';
import '../../settings/app_settings.dart';
import '../../steam/steam.dart';
import '../../steam/steam_debug_sheet.dart';
import '../theme/app_theme.dart';
import 'online/safety_sheets.dart';
import 'online/game/gesture_picker.dart';
import 'screening_room_screen.dart';
import 'tutorial_screen.dart';
import '../../l10n/tutorial_strings.dart';

part 'settings_desktop.dart';

/// Dove vivranno informativa e termini sul web.
/// TODO(owner): pubblicare docs/legal/*.md a questi indirizzi (o cambiarli).
const privacyPolicyUrl = 'https://oberta.app/privacy';
const termsUrl = 'https://oberta.app/terms';

/// Le impostazioni, a pagina intera: un ufficio di legno scuro con le
/// targhette d'ottone. Audio, lingua, sala prove, account, privacy e dati.
class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final OnlineServices? online;

  /// Come si consegna il file dei dati esportati. Di base, il foglio di
  /// condivisione di iOS; i test lo sostituiscono.
  final Future<void> Function(String fileName, String json)? shareExport;

  /// Versione e build da mostrare; di base le legge dall'app.
  final String? versionLabel;

  SettingsScreen({super.key, AppSettings? settings, OnlineServices? online, this.shareExport, this.versionLabel})
    : settings = settings ?? AppSettings.instance,
      online = online ?? OnlineServices.instance;

  static Future<void> open(BuildContext context, {AppSettings? settings}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(settings: settings)));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<Profile?>? _profile;
  String? _profileFor;
  Future<String>? _version;
  bool _busy = false;

  OnlineAuth? get _auth => widget.online?.auth;

  Future<Profile?> _profileOf(String? userId) {
    if (_profileFor != userId || _profile == null) {
      _profileFor = userId;
      _profile = userId == null
          ? Future.value(null)
          : widget.online!.profiles.me().then<Profile?>((p) => p).catchError((_) => null);
    }
    return _profile!;
  }

  Future<String> _versionText() => _version ??= widget.versionLabel != null
      ? Future.value(widget.versionLabel)
      : PackageInfo.fromPlatform().then((info) => '${info.version} (${info.buildNumber})').catchError((_) => '—');

  Future<void> _defaultShare(String fileName, String json) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
  }

  Future<void> _export() async {
    final account = widget.online?.account;
    if (account == null) return;
    final s = SettingsStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final data = await account.exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final day = DateTime.now().toIso8601String().substring(0, 10);
      await (widget.shareExport ?? _defaultShare)('oberta-data-$day.json', json);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.exportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String? handle) async {
    final account = widget.online?.account;
    if (account == null) return;
    final s = SettingsStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.deleteTitle),
        content: Text(s.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(
            key: const Key('settings.delete.continue'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteContinue, style: const TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final word = handle ?? s.deleteConfirmWord;
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => _TypeToConfirm(word: word, strings: s),
    );
    if (second != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await account.deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(s.deleteDone)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLegal(String title, String kind, String url) {
    final s = SettingsStrings.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalScreen(title: title, asset: 'docs/legal/${kind}_${s.legalAsset}.md', url: url),
      ),
    );
  }

  /// Solo su desktop: modo della finestra, risoluzione e orientamento,
  /// salvati su questo dispositivo.
  Widget _screenSection(AppSettings settings) {
    final d = DesktopStrings.of(context);
    Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) pick, String key) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                ChoiceChip(
                  key: Key('settings.$key.${label(value)}'),
                  label: Text(label(value)),
                  selected: selected == value,
                  selectedColor: AppColors.gold.withValues(alpha: 0.3),
                  onSelected: (_) => pick(value),
                ),
            ],
          ),
        );
    return _Section(
      title: d.screen,
      children: [
        ListTile(leading: const Icon(Icons.desktop_windows, color: AppColors.gold), title: Text(d.windowMode)),
        chips(
          DesktopWindowMode.values,
          settings.windowMode,
          (m) => switch (m) {
            DesktopWindowMode.windowed => d.windowed,
            DesktopWindowMode.fullscreen => d.fullscreen,
            DesktopWindowMode.borderless => d.borderless,
          },
          (m) => settings.windowMode = m,
          'window',
        ),
        ListTile(
          leading: const Icon(Icons.aspect_ratio, color: AppColors.gold),
          title: Text(d.resolution),
          subtitle: Text(d.resolutionHint),
        ),
        chips(DesktopResolutions.all, settings.resolution, DesktopResolutions.label, (r) => settings.resolution = r,
            'resolution'),
        ListTile(leading: const Icon(Icons.screen_rotation, color: AppColors.gold), title: Text(d.orientation)),
        chips(
          DesktopOrientation.values,
          settings.orientation,
          (o) => o == DesktopOrientation.landscape ? d.landscape : d.portrait,
          (o) => settings.orientation = o,
          'orientation',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final auth = _auth;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?auth]),
      builder: (context, _) {
        final t = AppStrings.of(context);
        final s = SettingsStrings.of(context);
        final signedIn = auth != null && auth.signedIn;
        if (DesktopCanvas.of(context)) return _DesktopSettings(host: this);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: const Color(0xFF2A1E16),
            foregroundColor: AppColors.gold,
            centerTitle: true,
            title: Text(t.settingsTitle, style: AppText.display(18)),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: SizedBox(
                height: 2,
                width: double.infinity,
                child: ColoredBox(color: Color(0x88C9A227)),
              ),
            ),
          ),
          body: ContentWidth(
            child: Stack(
              children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: s.audio,
                      children: [
                        SwitchListTile(
                          value: settings.soundOn,
                          activeThumbColor: AppColors.gold,
                          title: Text(t.sound),
                          subtitle: Text(t.soundHint),
                          secondary: const Icon(Icons.music_note, color: AppColors.gold),
                          onChanged: (on) => settings.soundOn = on,
                        ),
                        _VolumeTile(
                          icon: Icons.library_music,
                          label: t.musicVolumeLabel,
                          value: settings.musicVolume,
                          enabled: settings.soundOn,
                          onChanged: (v) => settings.musicVolume = v,
                        ),
                        _VolumeTile(
                          icon: Icons.graphic_eq,
                          label: t.effectsVolumeLabel,
                          value: settings.effectsVolume,
                          enabled: settings.soundOn,
                          onChanged: (v) => settings.effectsVolume = v,
                        ),
                        SwitchListTile(
                          value: settings.memeMode,
                          activeThumbColor: AppColors.gold,
                          title: Text(t.memeMode),
                          subtitle: Text(t.memeModeHint),
                          secondary: const Icon(Icons.sentiment_very_satisfied, color: AppColors.gold),
                          onChanged: settings.soundOn ? (on) => settings.memeMode = on : null,
                        ),
                      ],
                    ),
                    if (DesktopPlatform.isDesktop) _screenSection(settings),
                    _Section(
                      title: s.languageSection,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.translate, color: AppColors.gold),
                          title: Text(t.languageSetting),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final language in <AppLanguage?>[null, ...AppLanguage.values])
                                ChoiceChip(
                                  label: Text(language?.nativeName ?? t.languageAutomatic),
                                  selected: settings.language == language,
                                  selectedColor: AppColors.gold.withValues(alpha: 0.3),
                                  onSelected: (_) => settings.language = language,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _Section(
                      title: s.game,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.movie_filter, color: AppColors.gold),
                          title: Text(t.rehearsal),
                          subtitle: Text(t.rehearsalHint),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.of(context)
                                  .push(MaterialPageRoute<void>(builder: (_) => const ScreeningRoomScreen())),
                        ),
                        ListTile(
                          key: const Key('settings.tutorial'),
                          leading: const Icon(Icons.school_outlined, color: AppColors.gold),
                          title: Text(TutorialStrings.of(context).replay),
                          subtitle: Text(TutorialStrings.of(context).replayHint),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => TutorialScreen.open(context, settings: widget.settings),
                        ),
                      ],
                    ),
                    if (auth != null)
                      FutureBuilder<Profile?>(
                        future: _profileOf(auth.userId),
                        builder: (context, snapshot) {
                          final handle = snapshot.data?.handle;
                          return _Section(
                            title: s.account,
                            children: [
                              if (!signedIn)
                                ListTile(
                                  leading: const Icon(Icons.person_outline, color: AppColors.gold),
                                  title: Text(s.notSignedIn),
                                )
                              else ...[
                                ListTile(
                                  leading: const Icon(Icons.badge_outlined, color: AppColors.gold),
                                  title: Text(handle != null ? s.signedInAs(handle) : s.signedInNoHandle),
                                ),
                                if (widget.online?.links case final links? when links.providers.isNotEmpty)
                                  ListTile(
                                    key: const Key('settings.link'),
                                    leading: const Icon(Icons.link, color: AppColors.gold),
                                    title: Text(DesktopStrings.of(context).linkAccount),
                                    subtitle: Text(DesktopStrings.of(context).linkHint),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => showLinkAccount(context, links: links),
                                  ),
                                ListTile(
                                  leading: const Icon(Icons.logout, color: AppColors.gold),
                                  title: Text(t.online.signOut),
                                  onTap: auth.signOut,
                                ),
                                // Su Steam e sul desktop non si elimina l'account da qui:
                                // la richiesta va scritta (vedi l'informativa). Sul
                                // telefono resta, come vuole Apple (5.1.1(v)).
                                if (widget.online?.account != null && !DesktopPlatform.isDesktop)
                                  ListTile(
                                    key: const Key('settings.delete'),
                                    leading: const Icon(Icons.delete_forever, color: AppColors.accent),
                                    title: Text(s.deleteAccount, style: const TextStyle(color: AppColors.accent)),
                                    subtitle: Text(s.deleteHint),
                                    onTap: _busy ? null : () => _delete(handle),
                                  ),
                              ],
                            ],
                          );
                        },
                      ),
                    _Section(
                      title: s.privacy,
                      children: [
                        ListTile(
                          key: const Key('settings.rules'),
                          leading: const Icon(Icons.menu_book_outlined, color: AppColors.gold),
                          title: Text(SafetyStrings.of(context).rulesTitle),
                          subtitle: Text(SafetyStrings.of(context).rulesHint),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showCommunityRules(context),
                        ),
                        if (signedIn && widget.online != null)
                          PublicProfileToggle(
                            profiles: widget.online!.profiles,
                            builder: (context, value, onChanged) => SwitchListTile(
                              key: const Key('settings.publicProfile'),
                              secondary: const Icon(Icons.badge_outlined, color: AppColors.gold),
                              title: Text(StatsStrings.of(context).publicSwitch),
                              subtitle: Text(StatsStrings.of(context).publicSwitchHint),
                              value: value ?? true,
                              onChanged: value == null ? null : onChanged,
                            ),
                          ),
                        if (signedIn && widget.online?.reactions != null)
                          PublicProfileToggle.gestures(
                            profiles: widget.online!.profiles,
                            builder: (context, value, onChanged) => SwitchListTile(
                              key: const Key('settings.tableGestures'),
                              secondary: const Icon(Icons.back_hand_outlined, color: AppColors.gold),
                              title: Text(GestureStrings.of(context).settingTitle),
                              subtitle: Text(GestureStrings.of(context).settingHint),
                              value: value ?? true,
                              onChanged: value == null ? null : onChanged,
                            ),
                          ),
                        if (signedIn && widget.online?.safety != null)
                          ListTile(
                            key: const Key('settings.blocked'),
                            leading: const Icon(Icons.block, color: AppColors.gold),
                            title: Text(SafetyStrings.of(context).blockedPlayers),
                            subtitle: Text(SafetyStrings.of(context).blockedHint),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BlockedPlayersScreen(safety: widget.online!.safety!),
                              ),
                            ),
                          ),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.gold),
                          title: Text(s.privacyPolicy),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openLegal(s.privacyPolicy, 'privacy', privacyPolicyUrl),
                        ),
                        ListTile(
                          leading: const Icon(Icons.gavel, color: AppColors.gold),
                          title: Text(s.terms),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openLegal(s.terms, 'terms', termsUrl),
                        ),
                        if (signedIn && widget.online?.account != null)
                          ListTile(
                            key: const Key('settings.export'),
                            leading: const Icon(Icons.download, color: AppColors.gold),
                            title: Text(s.exportData),
                            subtitle: Text(s.exportHint),
                            onTap: _busy ? null : _export,
                          ),
                      ],
                    ),
                    _Section(
                      title: s.about,
                      children: [
                        FutureBuilder<String>(
                          future: _versionText(),
                          builder: (context, snapshot) => ListTile(
                            leading: const Icon(Icons.info_outline, color: AppColors.gold),
                            title: Text(s.version),
                            trailing: Text(snapshot.data ?? '…', style: AppText.body),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.favorite_border, color: AppColors.gold),
                          title: Text(s.credits),
                          subtitle: Text(s.creditsBody),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Una sezione: targhetta d'ottone col titolo, e un pannello di legno.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE2C46A), Color(0xFFA9832A)]),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF2A1E16),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A1F), Color(0xFF2A1E16)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// Il secondo «sei sicuro?»: si conferma solo scrivendo la parola giusta.
class _TypeToConfirm extends StatefulWidget {
  final String word;
  final SettingsStrings strings;

  const _TypeToConfirm({required this.word, required this.strings});

  @override
  State<_TypeToConfirm> createState() => _TypeToConfirmState();
}

class _TypeToConfirmState extends State<_TypeToConfirm> {
  String _typed = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final ok = _typed.trim().toLowerCase() == widget.word.toLowerCase();
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(s.deleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.deleteTypePrompt(widget.word)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('settings.delete.word'),
            autofocus: true,
            autocorrect: false,
            onChanged: (value) => setState(() => _typed = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
        TextButton(
          key: const Key('settings.delete.confirm'),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: Text(s.deleteForever, style: TextStyle(color: ok ? AppColors.accent : AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _VolumeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _VolumeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(label),
      subtitle: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              divisions: 20,
              activeColor: AppColors.gold,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${(value * 100).round()}%', textAlign: TextAlign.end, style: AppText.body),
          ),
        ],
      ),
    );
  }
}

/// Informativa o termini, letti dal file in docs/legal come pagina carta
/// avorio: titoli, paragrafi ed elenchi. La nota per i revisori (le righe
/// che cominciano con «>») non si mostra.
class LegalScreen extends StatelessWidget {
  final String title;
  final String asset;
  final String url;

  const LegalScreen({super.key, required this.title, required this.asset, required this.url});

  static List<Widget> render(String markdown) {
    final widgets = <Widget>[];
    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty || line.startsWith('>')) continue;
      final text = line.replaceAll('**', '');
      if (text.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(text.substring(2), style: AppText.display(22, color: const Color(0xFF2A1E16))),
          ),
        );
      } else if (text.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(
              text.substring(3),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B1A1F),
              ),
            ),
          ),
        );
      } else if (text.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(color: Color(0xFF2A1E16), fontSize: 15)),
                Expanded(child: Text(text.substring(2), style: _paper)),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: _paper),
          ),
        );
      }
    }
    return widgets;
  }

  static const _paper = TextStyle(color: Color(0xFF2A1E16), fontSize: 15, height: 1.45);

  @override
  Widget build(BuildContext context) {
    final s = SettingsStrings.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1E16),
        foregroundColor: AppColors.gold,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: s.openOnWeb,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EAD8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 2),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: render(text)),
            ),
          );
        },
      ),
    );
  }
}
