import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/safety.dart';
import 'package:oberta/online/voice/voice_controller.dart';
import 'package:oberta/online/voice/livekit_voice_engine.dart';
import 'package:oberta/online/voice/voice_engine.dart';
import 'package:oberta/settings/app_settings.dart';
import 'package:oberta/settings/settings_store.dart';
import 'package:oberta/ui/screens/online/voice/voice_dock.dart';

/// Un LiveKit finto: chi c'è, chi parla, il microfono, ogni chiamata.
class _Engine extends VoiceEngine {
  final List<String> calls = [];
  bool _connected = false;
  bool _mic = false;
  Set<String> others = {};
  Set<String> talking = {};
  Set<String> unheard = {};
  Set<String> deafTo = {};
  String? self;

  @override
  bool get connected => _connected;
  @override
  Set<String> get participants => _connected ? others : const {};
  @override
  Set<String> get speaking => talking;
  @override
  String? get selfIdentity => self;
  @override
  bool get microphoneOn => _mic;

  @override
  Future<void> connect(String url, String token) async {
    calls.add('connect $token');
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    if (_connected) calls.add('disconnect');
    _connected = false;
    _mic = false;
  }

  @override
  Future<bool> setMicrophone(bool on) async {
    calls.add('mic $on');
    _mic = on;
    return true;
  }

  @override
  Future<void> setPrivacy({required Set<String> unheard, required Set<String> deafTo}) async {
    this.unheard = unheard;
    this.deafTo = deafTo;
  }

  @override
  Future<void> dispose() => disconnect();
}

/// Il server finto: risponde con [next], e conta le domande.
class _Server implements VoiceTokenSource {
  VoiceGrant next = VoiceGrant.none;
  VoiceRefused? refuse;
  int asked = 0;

  @override
  Future<VoiceGrant> grant(String roomId) async {
    asked++;
    if (refuse case final r?) throw r;
    return next;
  }
}

VoiceGrant _room(String room, {bool publish = true, String token = 't'}) => VoiceGrant(
  room: room,
  kind: 'day',
  identity: 's1',
  url: 'wss://lk',
  token: token,
  canPublish: publish,
  canSubscribe: true,
);

void main() {
  late _Engine engine;
  late _Server server;
  late AppSettings settings;
  late List<bool> ducks;

  VoiceController make({VoiceMode mode = VoiceMode.mic, bool ptt = false}) {
    settings = AppSettings(MemorySettingsStore())
      ..voiceMode = mode
      ..voicePushToTalk = ptt;
    return VoiceController(source: server, roomId: 'r', engine: engine, settings: settings, duck: ducks.add);
  }

  setUp(() {
    engine = _Engine();
    server = _Server();
    ducks = [];
    BlockedPlayers.clear();
    VoiceController.engineFactory = () => engine;
  });
  tearDown(() => VoiceController.engineFactory = LiveKitVoiceEngine.new);

  test('a new phase asks the server again; the same room is kept, a new one is joined', () async {
    final c = make();
    server.next = _room('day-1');
    c.phase('discussion-1');
    await pumpEventQueue();
    expect(engine.calls.where((x) => x.startsWith('connect')), ['connect t']);
    c.phase('discussion-1');
    await pumpEventQueue();
    expect(server.asked, 1, reason: 'the same phase asks nothing');

    c.phase('vote-1');
    await pumpEventQueue();
    expect(server.asked, 2);
    expect(engine.calls.where((x) => x.startsWith('connect')).length, 1, reason: 'same room, same rights: no reconnect');

    server.next = _room('family-1', token: 'f');
    c.phase('night-2');
    await pumpEventQueue();
    expect(engine.calls, containsAllInOrder(['disconnect', 'connect f']));
    c.dispose();
  });

  testWidgets('no room: disconnected; the server says when to ask again and is asked then', (tester) async {
    final c = make();
    server.next = _room('day-1');
    c.phase('vote-1');
    await tester.pump();
    expect(engine.connected, isTrue);

    // The night is published but not started: nobody is anywhere.
    server.next = const VoiceGrant(retryIn: Duration(seconds: 2));
    c.phase('night-2');
    await tester.pump();
    expect(engine.connected, isFalse, reason: 'the day closes at once');
    expect(server.asked, 2);

    server.next = _room('family-2');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(server.asked, 2, reason: 'not before the server time');
    await tester.pump(const Duration(milliseconds: 900));
    expect(server.asked, 3);
    expect(engine.connected, isTrue);
    c.dispose();
  });

  test('the microphone: only in mic mode, only with the right, open or held', () async {
    var c = make(mode: VoiceMode.listen);
    server.next = _room('day-1');
    await c.refresh();
    expect(engine.microphoneOn, isFalse, reason: 'listen only never transmits');
    c.dispose();

    engine = _Engine();
    c = make();
    server.next = _room('day-1', publish: false);
    await c.refresh();
    expect(engine.microphoneOn, isFalse, reason: 'the dead and the silenced do not transmit');
    c.dispose();

    engine = _Engine();
    c = make();
    server.next = _room('day-1');
    await c.refresh();
    expect(engine.microphoneOn, isTrue, reason: 'open mic');
    c.toggleSelfMute();
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse);
    c.dispose();

    engine = _Engine();
    c = make(ptt: true);
    server.next = _room('day-1');
    await c.refresh();
    expect(engine.microphoneOn, isFalse);
    c.hold(true);
    await pumpEventQueue();
    expect(engine.microphoneOn, isTrue);
    c.hold(false);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse);
    c.dispose();
  });

  test('desktop push to talk: V held talks, never while typing', () async {
    final c = make(ptt: true);
    server.next = _room('day-1');
    await c.refresh();
    const v = PhysicalKeyboardKey.keyV;
    expect(c.handleKey(const KeyDownEvent(physicalKey: v, logicalKey: LogicalKeyboardKey.keyV, timeStamp: Duration.zero)), isTrue);
    await pumpEventQueue();
    expect(engine.microphoneOn, isTrue);
    expect(c.handleKey(const KeyUpEvent(physicalKey: v, logicalKey: LogicalKeyboardKey.keyV, timeStamp: Duration.zero)), isTrue);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse);
    const b = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyB, logicalKey: LogicalKeyboardKey.keyB, timeStamp: Duration.zero);
    expect(c.handleKey(b), isFalse);
    c.dispose();
  });

  test('blocked players never hear us and are never heard; a mute is only ours', () async {
    final profiles = {'s2': 'p2', 's3': 'p3'};
    final VoiceDirectory dir = (profileOf: (String id) => profiles[id], nameOf: (String id) => id);
    engine.others = {'s2', 's3'};
    final v = VoiceController.acquire(server, 'room-b', directory: dir);
    server.next = _room('day-1');
    await v.refresh();
    expect(engine.deafTo, isEmpty);
    BlockedPlayers.add('p3');
    await pumpEventQueue();
    expect(engine.deafTo, {'s3'});
    expect(engine.unheard, {'s3'});
    v.toggleMute('s2');
    await pumpEventQueue();
    expect(engine.unheard, {'s2', 's3'});
    expect(engine.deafTo, {'s3'}, reason: 'a mute does not stop them hearing us');
    v.release(directory: dir);
  });

  test('shared per room, off leaves, a refusal stops asking', () async {
    engine.others = {'s2'};
    final a = VoiceController.acquire(server, 'room-s');
    final b = VoiceController.acquire(server, 'room-s');
    expect(identical(a, b), isTrue);
    server.next = _room('lobby');
    await a.refresh();
    expect(engine.connected, isTrue);
    AppSettings.instance.voiceMode = VoiceMode.off;
    await pumpEventQueue();
    expect(engine.connected, isFalse);
    AppSettings.instance.voiceMode = VoiceMode.listen;
    await pumpEventQueue();
    expect(engine.connected, isTrue);

    server.refuse = const VoiceRefused(VoiceRefusal.unavailable);
    await a.refresh();
    expect(a.unavailable, isTrue);
    expect(engine.connected, isFalse);
    final asked = server.asked;
    a.phase('another');
    await pumpEventQueue();
    expect(server.asked, asked, reason: 'voice off for this room: no more questions');
    a.release();
    b.release();
  });

  test('the music ducks while someone else is in the room, and comes back', () async {
    engine.others = {'s2'};
    final c = make(mode: VoiceMode.listen);
    server.next = _room('day-1');
    await c.refresh();
    expect(ducks, [true]);
    server.next = VoiceGrant.none;
    await c.refresh();
    expect(ducks, [true, false]);
    server.next = _room('day-1');
    await c.refresh();
    c.dispose();
    expect(ducks, [true, false, true, false], reason: 'leaving the screen gives the music back');
  });

  test('grants from the server', () {
    final g = VoiceGrant.fromJson({
      'room': 'ob-r-day-g-1',
      'kind': 'day',
      'identity': 's2',
      'url': 'wss://lk',
      'token': 'jwt',
      'canPublish': false,
      'canSubscribe': true,
      'expiresIn': 180,
    });
    expect([g.connects, g.canPublish, g.canSubscribe, g.expiresIn], [true, false, true, const Duration(minutes: 3)]);
    final wait = VoiceGrant.fromJson({'room': null, 'retryIn': 1700});
    expect([wait.connects, wait.retryIn], [false, const Duration(milliseconds: 1700)]);
  });

  testWidgets('the ring shows who is speaking; the dock hides where voice is off', (tester) async {
    final c = make();
    server.next = _room('day-1');
    await c.refresh();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          VoiceDock(controller: c),
          VoiceRing(controller: c, identity: 's2', width: 80, child: const SizedBox(width: 80, height: 100)),
        ]),
      ),
    ));
    double ring() => tester.widget<AnimatedOpacity>(find.byKey(const Key('voice.ring.s2'))).opacity;
    expect(ring(), 0);
    engine.talking = {'s2'};
    engine.onChanged?.call();
    await tester.pump();
    expect(ring(), 1);
    expect(find.byKey(const Key('voice.talk')), findsOneWidget);

    server.refuse = const VoiceRefused(VoiceRefusal.unavailable);
    await c.refresh();
    await tester.pump();
    expect(find.byKey(const Key('voice.talk')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
