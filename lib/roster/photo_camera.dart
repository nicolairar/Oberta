import 'dart:typed_data';

/// Da dove arriva una foto.
enum PhotoSource { camera, gallery }

/// Il telefono non lascia usare la fotocamera (o la galleria): permesso
/// negato, oppure vietato da chi amministra il telefono.
class PhotoAccessDenied implements Exception {
  const PhotoAccessDenied();
}

/// Chi scatta le foto segnaletiche. L'app vera usa la fotocamera del
/// telefono; i test ne passano una finta.
abstract class PhotoCamera {
  /// La fotocamera che l'app usa. Finché nessuno installa quella vera non
  /// scatta niente: è quella che trovano i test.
  static PhotoCamera instance = const NoCamera();

  /// Una foto già rimpicciolita e compressa, o `null` se chi stava
  /// scattando ci ha ripensato. Lancia [PhotoAccessDenied] senza permesso.
  Future<Uint8List?> take(PhotoSource source);
}

/// Una fotocamera che non scatta mai.
class NoCamera implements PhotoCamera {
  const NoCamera();

  @override
  Future<Uint8List?> take(PhotoSource source) async => null;
}
