import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/join_code.dart';
import 'package:oberta/online/online_config.dart';

void main() {
  test('un codice scritto male si ripulisce', () {
    expect(JoinCode.normalize('abc234'), 'ABC234');
    expect(JoinCode.normalize(' AB-C2 34 '), 'ABC234');
  });

  test('niente lettere che si confondono, e sei caratteri esatti', () {
    for (final bad in ['ABC23O', 'ABC231', 'ABCDEI', 'ABCDEL', 'ABC23', 'ABC2345', '']) {
      expect(JoinCode.normalize(bad), isNull, reason: bad);
    }
  });

  test('il QR della stanza porta il suo codice', () {
    expect(JoinCode.fromScan(JoinCode.qrPayload('XK7P2M')), 'XK7P2M');
    expect(JoinCode.fromScan('xk7p2m'), 'XK7P2M', reason: 'anche un codice nudo');
    expect(JoinCode.fromScan('https://example.com'), isNull);
  });

  test('l\'alfabeto è quello del server', () {
    expect(JoinCode.alphabet, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789');
  });

  test('senza config/supabase.json l\'online non c\'è', () {
    expect(OnlineConfig.compiled.isComplete, isFalse);
    expect(OnlineConfig.compiled.hasGoogle, isFalse);
    expect(const OnlineConfig(supabaseUrl: 'https://x.supabase.co', supabaseAnonKey: 'k').isComplete, isTrue);
  });
}
