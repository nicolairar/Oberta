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
/// Dentro [child] niente RepaintBoundary: i suoi cambi non arriverebbero fin
/// qui, e l'immagine resterebbe vecchia.
class Baked extends SingleChildRenderObjectWidget {
  /// Quanto il disegno esce dal suo riquadro (un'ombra, un alone): anche
  /// quello finisce nell'immagine.
  final EdgeInsets overflow;

  const Baked({super.key, this.overflow = EdgeInsets.zero, required Widget super.child});

  @override
  RenderBaked createRenderObject(BuildContext context) => RenderBaked(overflow: overflow);

  @override
  void updateRenderObject(BuildContext context, RenderBaked renderObject) => renderObject.overflow = overflow;
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
  RenderBaked({EdgeInsets overflow = EdgeInsets.zero}) : _overflow = overflow; // ignore: prefer_initializing_formals

  EdgeInsets get overflow => _overflow;
  EdgeInsets _overflow;
  set overflow(EdgeInsets value) {
    if (value == _overflow) return;
    _overflow = value;
    markNeedsPaint();
  }

  ui.Image? _image;
  Size? _imageSize;
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

  @override
  bool get isRepaintBoundary => true;

  void _drop() {
    _image?.dispose();
    _image = null;
    _imageSize = null;
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
    super.markNeedsPaint();
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
    super.detach();
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  _Placement? _placement() {
    final m = getTransformTo(null).storage;
    // Prospettiva, rotazioni, deformazioni, specchi: niente immagine.
    if (m[3] != 0 || m[7] != 0 || m[15] != 1 || m[1] != 0 || m[4] != 0) return null;
    final sx = m[0];
    if (sx <= 0 || !_sameScale(sx, m[5])) return null;
    // L'angolo dell'immagine, compreso quello che sborda.
    final x = m[12] - _overflow.left * sx;
    final y = m[13] - _overflow.top * sx;
    return (scale: sx, dx: x - x.floorToDouble(), dy: y - y.floorToDouble());
  }

  /// A fine fotogramma: se si è spostato di una frazione di pixel o ha
  /// cambiato scala senza ridisegnarsi (una pagina che scorre, uno zoom che
  /// finisce), appena sta fermo lo si ridisegna come si deve.
  void _watch() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _watching = false;
      if (!attached) return;
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
    _crisp = null;
    if (child == null || size.isEmpty) return;
    final place = _placement();
    if (place == null || _volatile || _unbakeable) {
      _drop();
      super.paint(context, offset);
      return;
    }
    final settled = _seen != null && _sameScale(place.scale, _seen!.scale);
    if (_image == null || _imageSize != size || (!_sameScale(_imageScale, place.scale) && settled)) {
      _drop();
      if (!_bake(place.scale)) {
        _unbakeable = true;
        super.paint(context, offset);
        return;
      }
    }
    final bounds = _overflow.inflateRect(Offset.zero & size);
    final scale = _imageScale;
    final exact = _sameScale(scale, place.scale);
    // Da fermo l'angolo dell'immagine cade su un pixel intero dello schermo.
    final shift = exact ? Offset(-place.dx / scale, -place.dy / scale) : Offset.zero;
    context.canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(0, 0, bounds.width * scale, bounds.height * scale),
      bounds.shift(offset + shift),
      Paint()..filterQuality = FilterQuality.low,
    );
    if (exact) _crisp = place;
  }

  bool _bake(double scale) {
    final bounds = _overflow.inflateRect(Offset.zero & size);
    final layer = OffsetLayer();
    final inner = PaintingContext(layer, bounds);
    super.paint(inner, Offset.zero);
    // ignore: invalid_use_of_protected_member
    inner.stopRecordingIfNeeded();
    if (!layer.supportsRasterization()) {
      layer.dispose();
      return false;
    }
    _image = layer.toImageSync(bounds, pixelRatio: scale);
    layer.dispose();
    _imageSize = size;
    _imageScale = scale;
    return true;
  }
}
