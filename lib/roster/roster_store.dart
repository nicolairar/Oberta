import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'portrait_registry.dart';
import 'roster.dart';
import 'roster_storage.dart';

/// L'elenco vivo: tiene in memoria quello che c'è sul telefono, lo cambia e
/// lo risalva a ogni modifica. La UI ascolta e ridisegna.
class RosterStore extends ChangeNotifier {
  static RosterStore _instance = RosterStore(MemoryRosterStorage());

  /// L'elenco che l'app usa. Finché nessuno ne installa uno vero vive in
  /// memoria, senza toccare il telefono: è quello che trovano i test. Dura
  /// quanto il processo, quindi un test che passa dal tavolo ne installa uno
  /// nuovo nel suo `setUp`, per non ereditare la gente del test di prima.
  static RosterStore get instance => _instance;

  /// Installa [store] come elenco dell'app, e le sue facce come quelle che
  /// i ritratti mostrano.
  static set instance(RosterStore store) {
    _instance = store;
    PortraitRegistry.instance = store.portraits;
  }

  final RosterStorage _storage;

  /// Le facce di chi è in elenco, per chi disegna i ritratti.
  final PortraitRegistry portraits = PortraitRegistry();

  Roster _roster = Roster.empty;
  final _images = <String, MemoryImage>{};
  Future<void>? _loading;
  bool _loaded = false;

  /// L'elenco ancora da scrivere, e se qualcuno lo sta già scrivendo.
  String? _unsaved;
  bool _saving = false;

  RosterStore(this._storage);

  Roster get roster => _roster;

  /// Falso finché l'elenco salvato non è stato letto.
  bool get isLoaded => _loaded;

  /// La foto di [member], pronta da mostrare.
  PortraitPhoto? photoOf(RosterMember member) {
    final image = _images[member.photo];
    return image == null ? null : PortraitPhoto(image, alignment: Alignment(member.photoX, member.photoY));
  }

  /// Legge l'elenco salvato. Si può chiamare quante volte si vuole: legge
  /// una volta sola.
  Future<void> load() async {
    if (!_loaded) await (_loading ??= _load());
  }

  Future<void> _load() async {
    var roster = Roster.empty;
    try {
      roster = Roster.decode(await _storage.readRoster());
      for (final member in roster.members) {
        final key = member.photo;
        if (key == null) continue;
        final bytes = await _storage.readPhoto(key);
        if (bytes == null || bytes.isEmpty) {
          // La foto non c'è più: la persona resta, col ritratto disegnato.
          roster = roster.withPhoto(member.id, null);
        } else {
          _images[key] = MemoryImage(bytes);
        }
      }
      await _storage.sweepPhotos(roster.photos);
    } catch (error, stack) {
      _report(error, stack, 'leggendo l\'elenco salvato');
    }
    _roster = roster;
    _loaded = true;
    _publish();
  }

  /// Aggiunge una persona, con la sua foto se [photo] c'è. Restituisce la
  /// persona com'è entrata in elenco: seduta, se al tavolo c'era posto.
  Future<RosterMember> add(
    String name, {
    Uint8List? photo,
    double photoX = defaultPhotoX,
    double photoY = defaultPhotoY,
  }) async {
    await load();
    // Prima si prova senza foto: un nome rifiutato non deve lasciare un
    // file orfano sul telefono.
    _roster.add(name);
    final key = photo == null ? null : await _keep(photo);
    final Roster next;
    try {
      next = _roster.add(name, photo: key, photoX: photoX, photoY: photoY);
    } on RosterError {
      if (key != null) await _discard(key);
      rethrow;
    }
    await _apply(next);
    return next.members.last;
  }

  Future<void> rename(String id, String name) async {
    await load();
    await _apply(_roster.rename(id, name));
  }

  /// Dà a una persona una foto nuova e butta quella di prima.
  Future<void> setPhoto(
    String id,
    Uint8List photo, {
    double photoX = defaultPhotoX,
    double photoY = defaultPhotoY,
  }) async {
    await load();
    if (_roster.byId(id) == null) return;
    final key = await _keep(photo);
    final member = _roster.byId(id);
    // Tolto dall'elenco mentre la foto si salvava: non resta nemmeno lei.
    if (member == null) return _discard(key);
    final old = member.photo;
    await _apply(_roster.withPhoto(id, key, x: photoX, y: photoY));
    if (old != null) await _discard(old);
  }

  /// Sposta l'inquadratura della foto che c'è già.
  Future<void> framePhoto(String id, double photoX, double photoY) async {
    await load();
    final key = _roster.byId(id)?.photo;
    if (key == null) return;
    await _apply(_roster.withPhoto(id, key, x: photoX, y: photoY));
  }

  /// Toglie la foto a una persona e la cancella dal telefono.
  Future<void> removePhoto(String id) async {
    await load();
    final key = _roster.byId(id)?.photo;
    if (key == null) return;
    await _apply(_roster.withPhoto(id, null));
    await _discard(key);
  }

  /// Toglie una persona dall'elenco, foto compresa.
  Future<void> remove(String id) async {
    await load();
    final key = _roster.byId(id)?.photo;
    await _apply(_roster.remove(id));
    if (key != null) await _discard(key);
  }

  /// Toglie tutti, e cancella tutte le foto.
  Future<void> clear() async {
    await load();
    final keys = _roster.photos;
    await _apply(_roster.cleared());
    for (final key in keys) {
      await _discard(key);
    }
  }

  /// Fa sedere o alzare una persona. Risponde `false` se voleva sedersi a
  /// un tavolo già pieno.
  Future<bool> seat(String id, bool seated) async {
    await load();
    final Roster next;
    try {
      next = _roster.seat(id, seated);
    } on RosterError {
      return false;
    }
    await _apply(next);
    return true;
  }

  Future<String> _keep(Uint8List photo) async {
    final key = await _storage.writePhoto(photo);
    _images[key] = MemoryImage(photo);
    return key;
  }

  Future<void> _discard(String key) async {
    _images.remove(key)?.evict();
    try {
      await _storage.deletePhoto(key);
    } catch (error, stack) {
      _report(error, stack, 'cancellando una foto');
    }
  }

  /// La memoria cambia subito, così chi guarda vede subito; poi si salva.
  /// Se una scrittura è già in corso non ne parte un'altra: chi sta
  /// scrivendo, finito, scrive anche l'elenco più recente.
  Future<void> _apply(Roster next) async {
    if (identical(next, _roster)) return;
    _roster = next;
    _publish();
    _unsaved = next.encode();
    if (_saving) return;
    _saving = true;
    try {
      while (_unsaved != null) {
        final json = _unsaved!;
        _unsaved = null;
        try {
          await _storage.writeRoster(json);
        } catch (error, stack) {
          _report(error, stack, 'salvando l\'elenco');
        }
      }
    } finally {
      _saving = false;
    }
  }

  void _publish() {
    portraits.replaceAll({
      for (final member in _roster.members)
        member.name: ?photoOf(member),
    });
    notifyListeners();
  }

  void _report(Object error, StackTrace stack, String doing) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'roster',
      context: ErrorDescription(doing),
    ));
  }
}
