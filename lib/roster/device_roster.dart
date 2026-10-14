import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'file_roster_storage.dart';
import 'photo_camera.dart';
import 'roster_store.dart';

/// Collega l'elenco al telefono vero: i file in una cartella privata
/// dell'app, le foto dalla fotocamera. Si chiama una volta, all'avvio.
///
/// È l'unico file che tocca i plugin: tutto il resto, test compresi, lavora
/// con le interfacce.
void installDeviceRoster() {
  WidgetsFlutterBinding.ensureInitialized();
  PhotoCamera.instance = DeviceCamera();
  RosterStore.instance = RosterStore(FileRosterStorage(_rosterDirectory))..load();
}

/// La cartella di servizio dell'app: privata, invisibile dall'app File, e
/// cancellata dal sistema insieme all'app.
Future<Directory> _rosterDirectory() async => Directory('${(await getApplicationSupportDirectory()).path}/roster');

/// La fotocamera del telefono. La foto arriva già piccola: il lato lungo
/// non supera [_maxSide], così il riquadro del ritratto è sui 600 punti e
/// ogni persona pesa un centinaio di kilobyte.
class DeviceCamera implements PhotoCamera {
  static const _maxSide = 800.0;
  static const _jpegQuality = 82;

  final _picker = ImagePicker();

  @override
  Future<Uint8List?> take(PhotoSource source) async {
    final XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _jpegQuality,
        // Della foto serve solo la faccia: senza i dati completi dello scatto
        // non c'è nemmeno da chiedere il permesso per la libreria.
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      if (error.code.contains('denied') || error.code.contains('restricted')) throw const PhotoAccessDenied();
      rethrow;
    }
    if (shot == null) return null;
    final bytes = await shot.readAsBytes();
    // Il plugin lascia una copia tra i file temporanei: l'unica che resta
    // sul telefono dev'essere quella dell'elenco.
    try {
      await File(shot.path).delete();
    } on FileSystemException {
      // Ci pensa il sistema, quando svuota i temporanei.
    }
    return bytes;
  }
}
