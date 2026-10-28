import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../roster/photo_camera.dart';
import '../../roster/portrait_registry.dart';
import '../../roster/roster.dart';
import '../../roster/roster_store.dart';
import '../theme/app_theme.dart';
import '../widgets/mugshot_frame.dart';
import '../widgets/scene_scaffold.dart';
import '../press.dart';
import '../widgets/noir_modal.dart';
import '../widgets/noir_notice.dart';

// I testi della schermata, tutti qui: la traduzione li prenderà da qui.

/// La scheda di una persona: il nome e la foto segnaletica. Senza [member]
/// è una scheda nuova, e dopo ogni schedato è pronta per il prossimo: il
/// telefono fa il giro del tavolo senza tornare indietro.
class PersonScreen extends StatefulWidget {
  final RosterStore roster;

  /// La fotocamera da usare. Senza, quella dell'app.
  final PhotoCamera? camera;

  /// Chi si sta modificando, o `null` per una scheda nuova.
  final RosterMember? member;

  const PersonScreen({super.key, required this.roster, this.camera, this.member});

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  AppStrings get _t => AppStrings.of(context);

  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  /// La foto di adesso: quella già salvata, o quella appena scattata.
  PortraitPhoto? _photo;

  /// I dati della foto appena scattata, ancora da salvare.
  Uint8List? _shot;
  bool _photoChanged = false;

  bool _submitted = false;
  bool _busy = false;

  /// Chi è appena stato schedato: finché c'è, si mostra il timbro.
  RosterMember? _booked;

  RosterStore get _store => widget.roster;
  PhotoCamera get _camera => widget.camera ?? PhotoCamera.instance;
  bool get _editing => widget.member != null;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    if (member != null) {
      _name.text = member.name;
      _photo = _store.photoOf(member);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  NameProblem? get _problem => _store.roster.checkName(_name.text, exceptId: widget.member?.id);

  /// Il nome vuoto si rimprovera solo a chi ha già provato a salvare.
  String? get _nameError => switch (_problem) {
    NameProblem.taken => _t.personNameTaken,
    NameProblem.tooLong => _t.personNameTooLong,
    NameProblem.empty when _submitted => _t.personNameEmpty,
    _ => null,
  };

  void _say(String message) {
    showNotice(context, message);
  }

  Future<void> _take(PhotoSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final shot = await _camera.take(source);
      if (!mounted || shot == null) return;
      setState(() {
        _shot = shot;
        _photo = PortraitPhoto(MemoryImage(shot));
        _photoChanged = true;
      });
      if (_name.text.trim().isEmpty) _nameFocus.requestFocus();
    } on PhotoAccessDenied {
      if (mounted) _say(_t.personCameraDenied);
    } catch (_) {
      if (mounted) _say(_t.personCameraFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _dropPhoto() {
    setState(() {
      _shot = null;
      _photo = null;
      _photoChanged = true;
    });
  }

  /// Trascinare la foto sposta l'inquadratura: giù il dito, giù la foto.
  void _drag(Offset delta, double side) {
    final photo = _photo;
    if (photo == null) return;
    // Una foto 4:3 sporge dal riquadro di un sesto per parte.
    final step = delta * (6 / side);
    setState(() {
      _photo = PortraitPhoto(
        photo.image,
        alignment: Alignment(
          (photo.alignment.x - step.dx).clamp(-1.0, 1.0),
          (photo.alignment.y - step.dy).clamp(-1.0, 1.0),
        ),
      );
      _photoChanged = true;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (_problem != null) return _nameFocus.requestFocus();
    setState(() => _busy = true);
    final name = _name.text;
    final frame = _photo?.alignment ?? const Alignment(defaultPhotoX, defaultPhotoY);
    final member = widget.member;
    try {
      if (member == null) {
        final booked = await _store.add(name, photo: _shot, photoX: frame.x, photoY: frame.y);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        FocusScope.of(context).unfocus();
        setState(() => _booked = booked);
        return;
      }
      if (Roster.cleanName(name) != member.name) await _store.rename(member.id, name);
      if (_photoChanged) {
        if (_shot != null) {
          await _store.setPhoto(member.id, _shot!, photoX: frame.x, photoY: frame.y);
        } else if (_photo == null) {
          await _store.removePhoto(member.id);
        } else {
          await _store.framePhoto(member.id, frame.x, frame.y);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } on RosterError {
      // L'elenco è cambiato sotto le dita: il campo dice cosa non va.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Scheda pulita per il prossimo che prende il telefono.
  void _nextPerson() {
    setState(() {
      _name.clear();
      _photo = null;
      _shot = null;
      _photoChanged = false;
      _submitted = false;
      _booked = null;
    });
  }

  Future<void> _remove() async {
    final member = widget.member!;
    final confirmed = await confirmNoir(
      context,
      title: _t.personRemoveTitle(member.name),
      body: _t.personRemoveBody,
      icon: Icons.person_remove_outlined,
      danger: true,
      cancel: _t.personRemoveCancel,
      confirm: _t.personRemoveConfirm,
    );
    if (confirmed != true) return;
    await _store.remove(member.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final booked = _booked;
    return SceneScaffold(
      resizeForKeyboard: false,
      appBar: AppBar(
        title: Text(_editing ? _t.personTitleEdit : _t.personTitleNew),
        actions: [
          if (_editing)
            IconButton(
              tooltip: _t.personRemoveTooltip,
              onPressed: pressed(_remove, Press.tap),
              icon: const Icon(Icons.person_remove_outlined, color: AppColors.textSecondary),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          // La città resta ferma: è il foglio che fa posto alla tastiera.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = min(constraints.maxWidth * 0.68, constraints.maxHeight * 0.34).clamp(150.0, 280.0);
              return SingleChildScrollView(
                // Il timbro si guarda dall'inizio, non da dove era arrivato il foglio.
                key: ValueKey(booked == null),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - 28)),
                  child: booked == null ? _form(side) : _bookedView(booked, side),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form(double side) {
    final photo = _photo;
    return Column(
      key: const ValueKey('form'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            GestureDetector(
              onTap: photo == null ? () => _take(PhotoSource.camera) : null,
              onVerticalDragUpdate: photo == null ? null : (drag) => _drag(drag.delta, side),
              onHorizontalDragUpdate: photo == null ? null : (drag) => _drag(drag.delta, side),
              child: SizedBox(
                width: side,
                child: ListenableBuilder(
                  listenable: _name,
                  builder: (context, _) => MugshotFrame(
                    name: _name.text,
                    photo: photo,
                    placeholder: _t.personPlacardEmpty,
                    caption: photo == null ? null : _t.personHintDrag,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SideButton(
                  icon: Icons.photo_library_outlined,
                  label: _t.personGallery,
                  onTap: _busy ? null : () => _take(PhotoSource.gallery),
                ),
                const SizedBox(width: 6),
                _Shutter(
                  label: photo == null ? _t.personShoot : _t.personReshoot,
                  onTap: _busy ? null : () => _take(PhotoSource.camera),
                ),
                const SizedBox(width: 6),
                _SideButton(
                  icon: Icons.no_photography_outlined,
                  label: _t.personNoPhoto,
                  onTap: photo == null || _busy ? null : _dropPhoto,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListenableBuilder(
              listenable: _name,
              builder: (context, _) => TextField(
                controller: _name,
                focusNode: _nameFocus,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
                onSubmitted: (_) => _submit(),
                cursorColor: AppColors.gold,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: _t.personNameHint,
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                  errorText: _nameError,
                  errorMaxLines: 2,
                  filled: true,
                  fillColor: AppColors.surface.withValues(alpha: 0.92),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: _border(AppColors.gold.withValues(alpha: 0.45)),
                  focusedBorder: _border(AppColors.gold, width: 2),
                  errorBorder: _border(AppColors.accent),
                  focusedErrorBorder: _border(AppColors.accent, width: 2),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: pressed(_busy ? null : _submit, Press.confirm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_editing ? _t.personSubmitEdit : _t.personSubmitNew),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _t.personPrivacy,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 12.5, height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookedView(RosterMember booked, double side) {
    return Column(
      key: const ValueKey('booked'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              width: side * 1.1,
              child: MugshotFrame(name: booked.name, photo: _store.photoOf(booked), stamp: _t.personStamp),
            ),
            const SizedBox(height: 24),
            Text(
              booked.seated ? _t.personBookedSeated(booked.name) : _t.personBookedWatching(booked.name),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(_t.personBookedPass, textAlign: TextAlign.center, style: AppText.body),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              if (!_store.roster.isFull) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: pressed(_nextPerson, Press.confirm),
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(_t.personNext)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: pressed(() => Navigator.of(context).pop(), Press.back),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(_t.personDone)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Il pulsante grande, tondo e rosso: quello che scatta.
class _Shutter extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Shutter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _RoundAction(
      label: label,
      labelColor: AppColors.textPrimary,
      onTap: pressed(onTap),
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textPrimary, width: 3),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 22)],
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          child: Icon(Icons.photo_camera, color: AppColors.textPrimary, size: 34),
        ),
      ),
    );
  }
}

/// I due pulsanti piccoli ai lati dello scatto.
class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SideButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _RoundAction(
      label: label,
      labelColor: AppColors.textSecondary,
      onTap: pressed(onTap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 24),
        ),
      ),
    );
  }
}

/// Un pulsante tondo con la sua scritta sotto: si tocca tutto, scritta
/// compresa, e chi non si può toccare è spento.
class _RoundAction extends StatelessWidget {
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;
  final Widget child;

  const _RoundAction({required this.label, required this.labelColor, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: pressed(onTap),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 92,
            child: Column(
              children: [
                child,
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: AppText.overline.copyWith(color: labelColor)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
