import 'dart:math';
import 'dart:typed_data';

/// Come cresce e si spegne un suono. [life] va da 0 a 1 lungo la sua durata.
typedef Envelope = double Function(double life);

abstract final class Env {
  /// Attacco secco e coda che si spegne: colpi, pizzicati, campane.
  /// [attack] è la frazione di durata che il suono impiega a salire.
  static Envelope hit([double sharpness = 5, double attack = 0.01]) =>
      (life) => min(1.0, life / attack) * exp(-sharpness * life) * min(1.0, (1 - life) * 20);

  /// Sale e scende morbido.
  static Envelope swell() => (life) => sin(pi * life);

  /// Tiene il livello, con i bordi sfumati per non fare "clic".
  static Envelope hold([double edge = 0.05]) => (life) => min(1.0, min(life, 1 - life) / edge);

  /// Cresce fino alla fine, e lì si interrompe.
  static Envelope rise([double power = 2]) =>
      (life) => pow(life, power).toDouble() * min(1.0, (1 - life) * 60);
}

/// Un nastro mono su cui si incide il suono, campione per campione.
///
/// Niente campioni registrati: ogni rumore nasce da onde, rumore bianco e
/// qualche filtro. Così il gioco suona senza portarsi dietro un solo file
/// audio, e senza licenze da controllare.
class Tape {
  static const rate = 32000;

  final Float64List samples;
  final Random _random;

  Tape(double seconds, {int seed = 7})
      : samples = Float64List((seconds * rate).ceil()),
        _random = Random(seed);

  double get seconds => samples.length / rate;

  /// Gli armonici di un'onda a dente di sega: il timbro ruvido di archi e ottoni.
  static List<(double, double)> saw(int count) => [for (var n = 1; n <= count; n++) (n.toDouble(), 1 / n)];

  /// Gli armonici dispari di un'onda quadra: il ronzio di un neon.
  static List<(double, double)> square(int count) =>
      [for (var n = 1; n <= count * 2; n += 2) (n.toDouble(), 1 / n)];

  void _write(double at, double length, double Function(int i, double life) sample) {
    final start = (at * rate).round();
    final count = max(1, (length * rate).round());
    for (var i = 0; i < count; i++) {
      final index = start + i;
      if (index < 0) continue;
      if (index >= samples.length) return;
      samples[index] += sample(i, i / count);
    }
  }

  /// Una nota di [from] Hz, che può scivolare fino a [to]. [partials] sono
  /// gli armonici: rapporto di frequenza e peso. [vibrato] è la frazione di
  /// cui la nota oscilla, [vibratoRate] volte al secondo.
  void tone(
    double at,
    double length,
    double from, {
    double? to,
    double gain = 0.5,
    Envelope? envelope,
    List<(double, double)> partials = const [(1, 1)],
    double vibrato = 0,
    double vibratoRate = 6,
  }) {
    final shape = envelope ?? Env.hit();
    final glide = to == null ? 1.0 : to / from;
    var phase = 0.0;
    _write(at, length, (i, life) {
      var freq = glide == 1 ? from : from * pow(glide, life);
      if (vibrato != 0) freq *= 1 + vibrato * sin(2 * pi * vibratoRate * i / rate);
      phase += 2 * pi * freq / rate;
      var value = 0.0;
      for (final (ratio, weight) in partials) {
        if (freq * ratio < rate * 0.45) value += weight * sin(phase * ratio);
      }
      return gain * shape(life) * value;
    });
  }

  /// Rumore bianco, tenuto sotto [lowpass] Hz (che può muoversi fino a
  /// [lowpassTo]) e sopra [highpass] Hz: soffi, spari, schianti.
  void noise(
    double at,
    double length, {
    double gain = 0.5,
    Envelope? envelope,
    double lowpass = 8000,
    double? lowpassTo,
    double highpass = 0,
  }) {
    final shape = envelope ?? Env.hit();
    final sweep = lowpassTo == null ? 1.0 : lowpassTo / lowpass;
    final high = 1 - exp(-2 * pi * highpass / rate);
    var low = 0.0;
    var floor = 0.0;
    _write(at, length, (i, life) {
      final cutoff = sweep == 1 ? lowpass : lowpass * pow(sweep, life);
      low += (1 - exp(-2 * pi * cutoff / rate)) * (_random.nextDouble() * 2 - 1 - low);
      floor += high * (low - floor);
      // Più si filtra, meno ne resta: si ridà un po' di volume.
      final makeup = min(4.0, sqrt(8000 / cutoff));
      return gain * shape(life) * makeup * (highpass > 0 ? low - floor : low);
    });
  }

  /// Una corda pizzicata (Karplus-Strong): un giro di rumore che rincorre se
  /// stesso e si addolcisce a ogni passaggio. Contrabbasso, pianoforte, arpa.
  void pluck(
    double at,
    double freq, {
    double length = 0.8,
    double gain = 0.5,
    double damping = 0.996,
    double brightness = 0.5,
  }) {
    final period = max(2, (rate / freq).round());
    final ring = Float64List(period);
    var last = 0.0;
    var peak = 0.0;
    for (var i = 0; i < period; i++) {
      last += brightness * (_random.nextDouble() * 2 - 1 - last);
      ring[i] = last;
      peak = max(peak, last.abs());
    }
    for (var i = 0; i < period; i++) {
      ring[i] /= peak;
    }
    var cursor = 0;
    _write(at, length, (i, life) {
      final value = ring[cursor];
      final next = (cursor + 1) % period;
      ring[cursor] = damping * 0.5 * (value + ring[next]);
      cursor = next;
      return gain * value * min(1.0, (1 - life) * 12);
    });
  }

  /// Incolla sul nastro un suono registrato (già a [rate] Hz, mono), a
  /// partire da [at] secondi.
  void sample(double at, Float64List data, {double gain = 1}) {
    _write(at, data.length / rate, (i, _) => i < data.length ? gain * data[i] : 0);
  }

  /// I campioni di un WAV a 16 bit mono, da -1 a 1. Tutto quello che non è
  /// il blocco dei dati (intestazioni, metadati) viene saltato.
  static Float64List decodeWav(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      if (id == 'data') {
        final count = min(size, bytes.length - offset - 8) ~/ 2;
        final out = Float64List(count);
        for (var i = 0; i < count; i++) {
          out[i] = data.getInt16(offset + 8 + i * 2, Endian.little) / 32768;
        }
        return out;
      }
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }
    return Float64List(0);
  }

  /// Mette tutto in una stanza: quattro echi corti che si rincorrono. Senza,
  /// ogni suono sembra uscire da una scatola di latta.
  void room({double mix = 0.22}) {
    final wet = Float64List(samples.length);
    for (final (delay, feedback) in const [(0.0297, 0.80), (0.0371, 0.78), (0.0411, 0.76), (0.0533, 0.74)]) {
      final gap = (delay * rate).round();
      final line = Float64List(samples.length);
      var damp = 0.0;
      for (var i = gap; i < samples.length; i++) {
        damp += 0.45 * (line[i - gap] - damp);
        line[i] = samples[i - gap] + feedback * damp;
        wet[i] += line[i];
      }
    }
    // Un passa-tutto in coda, per impastare gli echi tra loro.
    final gap = (0.005 * rate).round();
    final smooth = Float64List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final delayed = i >= gap ? wet[i - gap] : 0.0;
      final feedback = i >= gap ? smooth[i - gap] : 0.0;
      smooth[i] = -0.7 * wet[i] + delayed + 0.7 * feedback;
    }
    for (var i = 0; i < samples.length; i++) {
      samples[i] += mix * 0.25 * smooth[i];
    }
  }

  /// Il nastro finito, come file WAV a 16 bit. Il volume viene portato al
  /// massimo e i picchi arrotondati, così anche i passaggi piano si sentono
  /// dall'altoparlante di un telefono.
  Uint8List toWav() {
    var peak = 0.0;
    for (final sample in samples) {
      peak = max(peak, sample.abs());
    }
    const drive = 1.7;
    double squash(double x) {
      final e = exp(2 * x);
      return (e - 1) / (e + 1);
    }

    final ceiling = squash(drive);
    final bytes = ByteData(44 + samples.length * 2);
    void ascii(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, rate, Endian.little);
    bytes.setUint32(28, rate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final level = peak == 0 ? 0.0 : squash(drive * samples[i] / peak) / ceiling;
      bytes.setInt16(44 + i * 2, (level * 32000).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
