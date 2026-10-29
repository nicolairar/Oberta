import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Un disegno fermo e pesante (migliaia di mattoni, un ritratto pieno di
/// sfumature) fatto una volta sola in un'immagine grande quanto i pixel veri
/// dello schermo, e poi rimesso a ogni fotogramma con un colpo solo. Il
/// motore di adesso (Impeller) non tiene niente da parte: senza, rifà ogni
/// mattone a ogni fotogramma, anche quando a muoversi è solo la pioggia.
///
/// L'immagine si rifà quando [child] cambia, o quando la scala a cui si vede
/// cambia e poi si ferma (durante uno zoom resta quella di prima). Girato o
/// deformato (un manifesto storto, una carta che si volta) si disegna dal
/// vivo come sempre: un'immagine girata si sfocherebbe. Da fermo l'immagine
/// si posa sui pixel interi dello schermo, così resta nitida come l'originale.
///
/// Dentro [child] niente RepaintBoundary, a parte altri [Baked]: i cambi di
/// un RepaintBoundary non arriverebbero fin qui, e l'immagine resterebbe
/// vecchia. Anche [Opacity] lo è: dentro va [PlainOpacity]. Un [Baked]
/// dentro un altro invece avvisa quello fuori, che si rifà con lui.
class Baked extends SingleChildRenderObjectWidget {
  /// Quanto il disegno esce dal suo riquadro (un'ombra, un alone): anche
  /// quello finisce nell'immagine.
  final EdgeInsets overflow;

  /// Anche girato (un manifesto storto sul muro): allora l'immagine si fa al
  /// doppio dei pixel e si rimpicciolisce, così i testi restano nitidi.
  final bool tilted;

  /// Al punto esatto: l'immagine si fa col disegno dove cade davvero sullo
  /// schermo, frazioni di pixel comprese, ed è uguale al disegno dal vivo; i
  /// [Baked] che ha dentro (un ritratto, una cornice) ci cadono sui pixel
  /// interi come sullo schermo. Per un pezzo intero di interfaccia (un posto
  /// al tavolo). Fermo su un'altra frazione di pixel, l'immagine si rifà;
  /// mentre cambia scala si disegna dal vivo. Con dentro un RepaintBoundary
  /// che non sia un [Baked] (una cornice che si muove) resta dal vivo.
  final bool exact;

  const Baked({
    super.key,
    this.overflow = EdgeInsets.zero,
    this.tilted = false,
    this.exact = false,
    required Widget super.child,
  });

  @override
  RenderBaked createRenderObject(BuildContext context) => RenderBaked(overflow: overflow, tilted: tilted, exact: exact);

  @override
  void updateRenderObject(BuildContext context, RenderBaked renderObject) => renderObject
    ..overflow = overflow
    ..tilted = tilted
    ..exact = exact;
}

/// Come si vede l'origine di un [RenderBaked] sullo schermo: quanti pixel per
/// punto, e su che frazione di pixel cade.
typedef _Placement = ({double scale, double dx, double dy});

bool _sameScale(double a, double b) => (a - b).abs() <= a * 1e-6;

bool _same(_Placement? a, _Placement? b) {
  if (a == null || b == null) return a == b;
  return _sameScale(a.scale, b.scale) && (a.dx - b.dx).abs() < 1e-3 && (a.dy - b.dy).abs() < 1e-3;
}

class RenderBaked extends RenderProxyBox {
  RenderBaked({EdgeInsets overflow = EdgeInsets.zero, bool tilted = false, bool exact = false}) // ignore: prefer_initializing_formals
      : _overflow = overflow, // ignore: prefer_initializing_formals
        _tilted = tilted, // ignore: prefer_initializing_formals
        _exact = exact; // ignore: prefer_initializing_formals

  bool get exact => _exact;
  bool _exact;
  set exact(bool value) {
    if (value == _exact) return;
    _exact = value;
    markNeedsPaint();
  }

  bool get tilted => _tilted;
  bool _tilted;
  set tilted(bool value) {
    if (value == _tilted) return;
    _tilted = value;
    markNeedsPaint();
  }

  EdgeInsets get overflow => _overflow;
  EdgeInsets _overflow;
  set overflow(EdgeInsets value) {
    if (value == _overflow) return;
    _overflow = value;
    markNeedsPaint();
  }

  ui.Image? _image;
  Size? _imageSize;

  /// Dove sta l'immagine, nelle misure di qui: col punto esatto comincia sul
  /// pixel dello schermo appena prima dell'angolo, e la si fa per [_imagePlace].
  Rect? _imageRect;
  _Placement? _imagePlace;

  /// L'immagine tenuta da parte, per le prove (null: si disegna dal vivo).
  @visibleForTesting
  ui.Image? get debugImage => _image;
  double _imageScale = 0;

  /// Dove l'immagine è stata posata nitida l'ultima volta (null: dal vivo, o
  /// con la scala sbagliata), e dove l'ha visto l'ultimo controllo.
  _Placement? _crisp;
  _Placement? _seen;

  /// I fotogrammi contati dai controlli, e l'ultimo in cui [child] è cambiato.
  /// Chi cambia a ogni fotogramma (un'animazione) si disegna dal vivo.
  int _frame = 0;
  int _changed = -10;
  bool _volatile = false;
  bool _unbakeable = false;
  bool _watching = false;
  bool _resnap = false;
  bool _painted = false;

  @override
  bool get isRepaintBoundary => true;

  void _drop() {
    _image?.dispose();
    _image = null;
    _imageSize = null;
    _imageRect = null;
    _imagePlace = null;
  }

  @override
  void markNeedsPaint() {
    // Chi sta sotto è cambiato: l'immagine non vale più. Tranne quando la si
    // ridisegna solo per posarla sui pixel giusti.
    if (!_resnap) {
      _drop();
      if (_changed == _frame - 1) _volatile = true;
      _changed = _frame;
    }
    // Dentro l'immagine di un altro Baked: anche quella è da rifare, perché
    // il motore non ridisegna uno strato che non è sullo schermo. Una volta
    // sola finché non lo si ridisegna (uno nascosto chiederebbe sempre).
    final told = _marked;
    _marked = true;
    super.markNeedsPaint();
    if (!told && attached) _outer()?._innerChanged();
  }

  /// Da ridisegnare, e quello fuori lo sa già.
  bool _marked = true;

  /// Il Baked più vicino che ci ha dentro, se c'è.
  RenderBaked? _outer() {
    for (var node = parent; node != null; node = node.parent) {
      if (node is RenderBaked) return node;
    }
    return null;
  }

  void _innerChanged() {
    if (_image != null) markNeedsPaint();
  }

  /// Dentro c'è un RepaintBoundary che non è un Baked: i suoi cambi non
  /// arriverebbero qui, quindi niente immagine.
  bool _foreign() {
    var found = false;
    void visit(RenderObject node) {
      if (found) return;
      if (node.isRepaintBoundary && node is! RenderBaked) {
        found = true;
        return;
      }
      node.visitChildren(visit);
    }

    if (child case final child?) visit(child);
    return found;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _watch();
  }

  @override
  void detach() {
    _drop();
    _crisp = null;
    _seen = null;
    _painted = false;
    super.detach();
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  /// I pixel veri per punto dello schermo. [getTransformTo] si ferma alla
  /// radice e non conta il suo ingrandimento: senza, sul telefono (3 pixel
  /// per punto) l'immagine si farebbe a un terzo dei pixel e si sfocherebbe.
  double get _pixelRatio {
    final root = owner?.rootNode;
    return root is RenderView ? root.configuration.devicePixelRatio : 1;
  }

  /// Il lato più lungo di un'immagine, in pixel: oltre, la scheda video non
  /// la tiene (e la memoria se ne va).
  static const _largest = 4096.0;

  _Placement? _placement() {
    final m = getTransformTo(null).storage;
    if (m[3] != 0 || m[7] != 0 || m[15] != 1) return null;
    final ratio = _pixelRatio;
    if (m[1] != 0 || m[4] != 0) {
      // Girato: un'immagine più fitta dei pixel, posata dove capita. Le
      // deformazioni e gli specchi restano dal vivo.
      if (!_tilted) return null;
      final sx = sqrt(m[0] * m[0] + m[1] * m[1]);
      final sy = sqrt(m[4] * m[4] + m[5] * m[5]);
      if (sx <= 0 || !_sameScale(sx, sy) || (m[0] * m[4] + m[1] * m[5]).abs() > sx * sx * 1e-6) return null;
      if (m[0] * m[5] - m[1] * m[4] <= 0) return null;
      return (scale: sx * max(2.0, ratio), dx: -1, dy: -1);
    }
    final sx = m[0];
    if (sx <= 0 || !_sameScale(sx, m[5])) return null;
    // L'angolo dell'immagine, compreso quello che sborda, in pixel veri.
    final x = (m[12] - _overflow.left * sx) * ratio;
    final y = (m[13] - _overflow.top * sx) * ratio;
    return (scale: sx * ratio, dx: x - x.floorToDouble(), dy: y - y.floorToDouble());
  }

  /// A fine fotogramma: se si è spostato di una frazione di pixel o ha
  /// cambiato scala senza ridisegnarsi (una pagina che scorre, uno zoom che
  /// finisce), appena sta fermo lo si ridisegna come si deve.
  void _watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      // Mai disegnato (dietro un'opacità a zero, come l'alone di chi non
      // parla): non c'è niente da posare; si ricomincia a guardare quando
      // lo si disegna.
      if (!attached || !_painted) return;
      _frame++;
      final now = _placement();
      var again = false;
      if (_volatile && _changed < _frame - 1) {
        _volatile = false;
        again = true;
      }
      if (now != null && !_unbakeable && !_same(now, _crisp)) {
        if (_same(now, _seen)) {
          again = true;
        } else {
          // Al punto esatto un'immagine non si stira: mentre cambia scala
          // (un posto scelto che si ingrandisce) si disegna dal vivo.
          if (_exact && _image != null && !_sameScale(now.scale, _imageScale)) again = true;
          SchedulerBinding.instance.scheduleFrame();
        }
      }
      _seen = now;
      if (again) {
        _resnap = true;
        markNeedsPaint();
        _resnap = false;
      }
      _watch();
    }, debugLabel: 'Baked.watch');
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _marked = false;
    _crisp = null;
    if (!_painted) {
      _painted = true;
      _watch();
    }
    if (child == null || size.isEmpty) return;
    final place = _placement();
    if (place == null || _volatile || _unbakeable) {
      _drop();
      super.paint(context, offset);
      return;
    }
    if (_exact && place.dx >= 0) {
      _paintExact(context, offset, place);
      return;
    }
    // Troppo grande per una sola immagine a pixel pieni: un po' meno fitta.
    final bounds = _overflow.inflateRect(Offset.zero & size);
    final want = min(place.scale, _largest / max(bounds.width, bounds.height));
    final capped = want < place.scale;
    final settled = _seen != null && _sameScale(place.scale, _seen!.scale);
    if (_image == null || _imageSize != size || (!_sameScale(_imageScale, want) && settled)) {
      _drop();
      if (!_bake(want)) {
        _unbakeable = true;
        super.paint(context, offset);
        return;
      }
    }
    final scale = _imageScale;
    final exact = !capped && _sameScale(scale, place.scale);
    final turned = place.dx < 0;
    // Da fermo l'angolo dell'immagine cade su un pixel intero dello schermo.
    final shift = exact && !turned ? Offset(-place.dx / scale, -place.dy / scale) : Offset.zero;
    context.canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(0, 0, bounds.width * scale, bounds.height * scale),
      bounds.shift(offset + shift),
      // Pixel per pixel basta il filtro più semplice; ingrandita o
      // rimpicciolita (uno zoom, un manifesto girato) quello buono.
      Paint()..filterQuality = exact && !turned ? FilterQuality.low : FilterQuality.medium,
    );
    if (exact || (capped && _sameScale(scale, want))) _crisp = place;
  }

  /// [Baked.exact]: l'immagine vale solo per la scala e la frazione di pixel
  /// per cui è fatta.
  void _paintExact(PaintingContext context, Offset offset, _Placement place) {
    void live() {
      _drop();
      super.paint(context, offset);
    }

    final kept = _image != null && _imageSize == size;
    if (kept && _same(place, _imagePlace)) {
      _drawExact(context, offset);
      _crisp = place;
      return;
    }
    // Fermo dov'era alla fine dell'ultimo fotogramma (o appena arrivato).
    final still = _seen == null || _same(place, _seen);
    if (!still) {
      // Si sposta: la stessa immagine al suo posto, fra un pixel e l'altro,
      // finché si ferma; se cambia scala, dal vivo.
      if (kept && _sameScale(place.scale, _imageScale)) {
        _drawExact(context, offset);
      } else {
        live();
      }
      return;
    }
    final bounds = _overflow.inflateRect(Offset.zero & size);
    if (place.scale * max(bounds.width, bounds.height) > _largest || _foreign()) {
      // Dal vivo, e così resta finché non si sposta.
      live();
      _crisp = place;
      return;
    }
    _drop();
    if (!_bake(place.scale, at: place)) {
      _unbakeable = true;
      super.paint(context, offset);
      return;
    }
    _drawExact(context, offset);
    _crisp = place;
  }

  void _drawExact(PaintingContext context, Offset offset) {
    final image = _image!;
    context.canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      _imageRect!.shift(offset),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  /// Quante immagini si sono fatte finora, in tutta l'app: le prove delle
  /// prestazioni guardano che da fermi non se ne facciano.
  static int debugBakes = 0;

  /// [at]: col punto esatto, dove cade l'angolo sullo schermo. L'immagine
  /// allora comincia sul pixel intero appena prima, e il disegno ci sta
  /// dentro alla sua frazione di pixel.
  bool _bake(double scale, {_Placement? at}) {
    debugBakes++;
    final bounds = _overflow.inflateRect(Offset.zero & size);
    final area = at == null
        ? bounds
        : Rect.fromLTRB(bounds.left - at.dx / scale, bounds.top - at.dy / scale, bounds.right, bounds.bottom);
    final layer = OffsetLayer();
    final inner = PaintingContext(layer, area);
    super.paint(inner, Offset.zero);
    // ignore: invalid_use_of_protected_member
    inner.stopRecordingIfNeeded();
    if (!layer.supportsRasterization()) {
      layer.dispose();
      return false;
    }
    final image = _image = layer.toImageSync(area, pixelRatio: scale);
    layer.dispose();
    _imageSize = size;
    _imageScale = scale;
    _imageRect = Rect.fromLTWH(area.left, area.top, image.width / scale, image.height / scale);
    _imagePlace = at;
    return true;
  }
}

/// Un'[Opacity] senza strato suo: quella di Flutter è sempre un
/// RepaintBoundary, e dentro un [Baked] lo terrebbe dal vivo. Questa invece
/// finisce nell'immagine con tutto il resto, e quando cambia la fa rifare.
/// Piena disegna il figlio com'è; sotto, lo stesso strato di trasparenza di
/// [Opacity].
class PlainOpacity extends SingleChildRenderObjectWidget {
  final double opacity;

  const PlainOpacity({super.key, required this.opacity, super.child}) : assert(opacity >= 0 && opacity <= 1);

  @override
  RenderPlainOpacity createRenderObject(BuildContext context) => RenderPlainOpacity(opacity);

  @override
  void updateRenderObject(BuildContext context, RenderPlainOpacity renderObject) => renderObject.opacity = opacity;
}

class RenderPlainOpacity extends RenderProxyBox {
  RenderPlainOpacity(double opacity) : _alpha = ui.Color.getAlphaFromOpacity(opacity);

  int _alpha;

  set opacity(double value) {
    final alpha = ui.Color.getAlphaFromOpacity(value);
    if (alpha == _alpha) return;
    final compositing = alwaysNeedsCompositing;
    final visible = _alpha != 0;
    _alpha = alpha;
    if (compositing != alwaysNeedsCompositing) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
    if (visible != (_alpha != 0)) markNeedsSemanticsUpdate();
  }

  final _layer = LayerHandle<OpacityLayer>();

  @override
  bool get alwaysNeedsCompositing => child != null && _alpha > 0 && _alpha < 255;

  @override
  bool paintsChild(RenderBox child) => _alpha > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _alpha == 0) {
      _layer.layer = null;
      return;
    }
    if (_alpha == 255) {
      _layer.layer = null;
      super.paint(context, offset);
      return;
    }
    _layer.layer = context.pushOpacity(offset, _alpha, super.paint, oldLayer: _layer.layer);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null && _alpha != 0) visitor(child!);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}
