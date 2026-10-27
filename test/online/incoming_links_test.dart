import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/incoming_links.dart';

void main() {
  test('i ritorni di «Collega Steam» non vanno al vicolo', () async {
    final inbox = IncomingLinks();
    final steam = inbox.steamLinks.first;
    inbox.deliver(Uri.parse('oberta://steam-link?ticket=abc&state=s'));
    expect(inbox.take(), isNull);
    expect((await steam).queryParameters['ticket'], 'abc');
    inbox.deliver(Uri.parse('https://oberta.app/r/K7Q2MX'));
    expect(inbox.take(), Uri.parse('https://oberta.app/r/K7Q2MX'));
  });
}
