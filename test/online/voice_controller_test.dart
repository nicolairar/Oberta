import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/safety.dart';
import 'package:oberta/online/voice/voice_controller.dart';
import 'package:oberta/online/voice/livekit_voice_engine.dart';
import 'package:oberta/online/voice/mic_permission.dart';
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

  /// LiveKit che si riconnette da solo: per un attimo scollegato, il
  /// microfono rimesso in muto, poi di nuovo dentro.
  void reconnect() {
    _connected = true;
    _mic = false;
    onChanged?.call();
  }

  /// La stanza persa del tutto (il server che ci toglie, la rete).
  void lose() {
    _connected = false;
    _mic = false;
    onLost?.call();
  }
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

  VoiceController make({VoiceMode mode = VoiceMode.mic}) {
    settings = AppSettings(MemorySettingsStore())..voiceMode = mode;
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

  test('the microphone: only in mic mode, only with the right, only while held', () async {
    var c = make(mode: VoiceMode.listen);
    server.next = _room('day-1');
    await c.refresh();
    expect(engine.microphoneOn, isFalse, reason: 'listen only never transmits');
    c.dispose();

    engine = _Engine();
    c = make();
    server.next = _room('day-1', publish: false);
    await c.refresh();
    c.hold(true);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse, reason: 'the dead and the silenced do not transmit');
    expect(c.holding, isFalse, reason: 'no right, no hold');
    c.dispose();

    engine = _Engine();
    c = make();
    server.next = _room('day-1');
    await c.refresh();
    expect(engine.microphoneOn, isFalse, reason: 'there is no open mic: nothing goes out until held');
    c.hold(true);
    await pumpEventQueue();
    expect(engine.microphoneOn, isTrue);
    c.hold(false);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse);

    // Held when the right goes away (the day ends): the mic closes at once.
    c.hold(true);
    await pumpEventQueue();
    server.next = _room('day-1', publish: false);
    await c.refresh();
    expect([engine.microphoneOn, c.holding], [false, false]);
    c.dispose();
  });

  test('desktop push to talk: V held talks, never while typing', () async {
    final c = make();
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

  testWidgets('the ring shows who is speaking, a badge who is muted; the voice hides where it is off', (tester) async {
    final c = make();
    engine.others = {'s2'};
    server.next = _room('day-1');
    await c.refresh();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          VoiceDock(controller: c),
          VoiceTalkButton(controller: c),
          VoiceRing(controller: c, identity: 's2', width: 80, child: const SizedBox(width: 80, height: 100)),
        ]),
      ),
    ));
    await tester.pump();
    double ring() => tester.widget<AnimatedOpacity>(find.byKey(const Key('voice.ring.s2'))).opacity;
    expect(ring(), 0);
    engine.talking = {'s2'};
    engine.onChanged?.call();
    await tester.pump();
    expect(ring(), 1);
    expect(find.byKey(const Key('voice.talk')), findsOneWidget);
    expect(find.byKey(const Key('voice.muted.s2')), findsNothing);

    c.toggleMute('s2');
    await tester.pump();
    expect(ring(), 0, reason: 'a muted player shows no ring');
    expect(find.byKey(const Key('voice.muted.s2')), findsOneWidget);

    server.refuse = const VoiceRefused(VoiceRefusal.unavailable);
    await c.refresh();
    await tester.pump();
    expect(find.byKey(const Key('voice.talk')), findsNothing);
    expect(find.byKey(const Key('voice.settings')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('the big button: hold to talk, live while held, a reason when the rules say no', (tester) async {
    final c = make();
    server.next = _room('day-1');
    await c.refresh();
    var reason = 'Di notte parla solo la famiglia';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: VoiceTalkButton(controller: c, reason: (_) => reason))),
    ));
    String caption() => tester.widget<Text>(find.byKey(const Key('voice.talk.caption'))).data!;
    expect(tester.getSize(find.byKey(const Key('voice.talk'))).width, greaterThanOrEqualTo(64));
    expect(caption(), 'Tieni premuto');

    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('voice.talk'))));
    await tester.pump();
    expect(engine.microphoneOn, isTrue);
    expect(caption(), 'Ti sentono');
    await finger.up();
    await tester.pump();
    expect(engine.microphoneOn, isFalse);
    expect(caption(), 'Tieni premuto');

    // The night of the town: muted, with the reason, and a press says why.
    server.next = const VoiceGrant();
    await c.refresh();
    await tester.pump();
    expect(caption(), reason);
    await tester.tap(find.byKey(const Key('voice.talk')));
    await tester.pump();
    expect(engine.microphoneOn, isFalse);
    expect(find.text(reason), findsNWidgets(2), reason: 'the full reason as a notice');
    await tester.pump(const Duration(seconds: 6));

    // Listen only: no talk button at all.
    reason = '';
    settings.voiceMode = VoiceMode.listen;
    await tester.pump();
    expect(find.byKey(const Key('voice.talk')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('choosing the microphone asks the system at once; denied falls back to listen only', (tester) async {
    final c = make(mode: VoiceMode.listen);
    var asked = 0;
    var granted = false;
    var opened = 0;
    MicPermission.request = () async {
      asked++;
      return granted;
    };
    MicPermission.openSettings = () async => opened++;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => chooseVoiceMode(context, settings, VoiceMode.mic),
            child: const Text('mic'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mic'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice.micAsk')), findsOneWidget);
    expect(asked, 0, reason: 'first the two lines on what happens');
    await tester.tap(find.byKey(const Key('voice.micAllow')));
    await tester.pumpAndSettle();
    expect(asked, 1, reason: 'the system is asked right away, not at the first word');
    expect(settings.voiceMode, VoiceMode.listen);
    expect(find.byKey(const Key('voice.micDenied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('voice.openSettings')));
    await tester.pumpAndSettle();
    expect(opened, 1);

    granted = true;
    await tester.tap(find.text('mic'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voice.micAllow')));
    await tester.pumpAndSettle();
    expect([asked, settings.voiceMode], [2, VoiceMode.mic]);
    expect(find.byKey(const Key('voice.micDenied')), findsNothing);
    c.dispose();
  });

  testWidgets('a microphone chosen earlier is checked on entering the voice, once', (tester) async {
    debugResetVoiceMicCheck();
    final c = make();
    var asked = 0;
    MicPermission.request = () async {
      asked++;
      return false;
    };
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VoiceDock(controller: c))));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(settings.voiceMode, VoiceMode.listen, reason: 'denied: listen only');
    expect(find.byKey(const Key('voice.micDenied')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    debugResetVoiceMicCheck();
  });

  testWidgets('holding for 10 s keeps transmitting across syncs, phases, remounts and reconnects', (tester) async {
    debugResetVoiceMicCheck();
    MicPermission.request = () async => true;
    settings = AppSettings(MemorySettingsStore())..voiceMode = VoiceMode.mic;
    final c = VoiceController(
      source: server,
      roomId: 'r',
      engine: engine,
      settings: settings,
      duck: ducks.add,
      keepFresh: const Duration(seconds: 2),
    );
    server.next = _room('day-1');
    c.phase('discussion-1');
    await tester.pump();
    var dock = true;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return Column(children: [
            VoiceTalkButton(controller: c),
            // The chat strip comes and goes (a phase, the keyboard, the
            // room screen under the game): its voice icon with it.
            if (dock) VoiceDock(controller: c),
          ]);
        }),
      ),
    ));
    await tester.pump();

    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('voice.talk'))));
    await tester.pump();
    expect(engine.microphoneOn, isTrue);
    final askedBefore = server.asked;
    for (var tick = 1; tick <= 40; tick++) {
      await tester.pump(const Duration(milliseconds: 250));
      switch (tick) {
        case 8:
          c.phase('vote-1'); // The discussion becomes the vote: same room, same rights.
        case 12:
          rebuild(() => dock = false);
        case 16:
          rebuild(() => dock = true);
        case 20:
          c.refresh();
        case 24:
          engine.reconnect();
        case 28:
          engine.lose();
      }
      await tester.pump();
      if (tick == 28) {
        // Out of the room for a moment: the hold waits, and comes back.
        expect(c.holding, isTrue);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
      }
      expect(engine.microphoneOn, isTrue, reason: 'still held at ${tick * 250} ms');
      expect(tester.widget<Text>(find.byKey(const Key('voice.talk.caption'))).data, 'Ti sentono');
    }
    expect(server.asked, greaterThan(askedBefore + 3), reason: 'the server was asked again and again meanwhile');
    expect(engine.calls.where((x) => x == 'mic false'), isEmpty, reason: 'nothing ever turned the mic off');

    await finger.up();
    await tester.pump();
    expect(engine.microphoneOn, isFalse);
    expect(c.holding, isFalse);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    debugResetVoiceMicCheck();
  });

  test('a quick release while the mic is still starting turns it off; two holders need both to let go', () async {
    final c = make();
    server.next = _room('day-1');
    await c.refresh();
    c.hold(true);
    c.hold(false);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse, reason: 'released before the mic was on: it ends off');
    // Two holders (the button and V): the mic stays until both let go.
    c.hold(true);
    c.hold(true, by: VoiceController.keyboard);
    c.hold(false);
    await pumpEventQueue();
    expect(engine.microphoneOn, isTrue);
    c.hold(false, by: VoiceController.keyboard);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse);
    c.dispose();
  });

  test('the vote takes the floor: the mic closes at once, no reconnect; the next day reconnects', () async {
    final c = make();
    server.next = _room('day-1');
    c.phase('discussion-1');
    await pumpEventQueue();
    c.hold(true);
    await pumpEventQueue();
    expect(engine.microphoneOn, isTrue);

    server.next = _room('day-1', publish: false);
    c.phase('vote-1');
    await pumpEventQueue();
    expect([engine.microphoneOn, c.holding, c.canHold, engine.connected], [false, false, false, true]);
    expect(engine.calls.where((x) => x.startsWith('connect')).length, 1, reason: 'still in the day room, listening');
    c.hold(true);
    await pumpEventQueue();
    expect(engine.microphoneOn, isFalse, reason: 'no hold during the vote');

    // More rights need the new token.
    server.next = _room('day-2', token: 'd2');
    c.phase('discussion-2');
    await pumpEventQueue();
    expect(engine.calls.last, 'connect d2');
    expect(c.canHold, isTrue);
    c.dispose();
  });
}
