import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../online/game/game_backend.dart';
import '../../../../online/game/game_client.dart';
import '../../../../online/game/game_schedule.dart';
import '../../../../rules/game_engine.dart';
import '../../../../rules/role.dart';
import '../../../../sound/meme_beat.dart';

/// Quello che il regista dei meme guarda della partita online: solo fatti
/// pubblici, gli stessi su ogni telefono. Mai il proprio ruolo, la propria
/// mossa o la chat della famiglia: un meme lo sente chi è nella stanza.
@immutable
class MemeSnapshot {
  final Stage? stage;
  final int round;

  /// I voti della piazza: chi → chi (`null`: astenuto).
  final Map<String, String?> votes;
  final Set<String> offline;

  /// L'alba di questo giro, se c'è.
  final int? dawnRound;
  final int victims;
  final int saves;
  final bool silenced;
  final bool scoopMafia;

  /// Il verdetto di questo giro: condannato e se era della famiglia.
  final int? lynchRound;
  final String? condemned;
  final bool condemnedMafia;
  final Team? winner;

  /// Se a vincere è stato chi tiene questo telefono.
  final bool iWon;

  /// I messaggi della piazza scritti dagli altri, con l'ora.
  final List<DateTime> dayChat;
  final Duration timeLeft;

  const MemeSnapshot({
    this.stage,
    this.round = 0,
    this.votes = const {},
    this.offline = const {},
    this.dawnRound,
    this.victims = 0,
    this.saves = 0,
    this.silenced = false,
    this.scoopMafia = false,
    this.lynchRound,
    this.condemned,
    this.condemnedMafia = false,
    this.winner,
    this.iWon = false,
    this.dayChat = const [],
    this.timeLeft = Duration.zero,
  });

  static MemeSnapshot of(GameClient client) {
    final board = client.board;
    if (board == null) return const MemeSnapshot();
    final view = board.view;
    final dawn = view.lastDawn;
    final lynch = view.lastLynch;
    final mine = client.seat?.view.seat.id;
    return MemeSnapshot(
      stage: board.schedule?.stage,
      round: board.schedule?.round ?? view.round,
      votes: {for (final vote in view.dayVotes) vote.voter.id: vote.target?.id},
      offline: board.offline,
      dawnRound: dawn?.round,
      victims: dawn?.victims.length ?? 0,
      saves: dawn?.attacks.where((attack) => attack.outcome != AttackOutcome.killed).length ?? 0,
      silenced: dawn?.silenced != null,
      scoopMafia: dawn?.scoop?.team == Team.mafia,
      lynchRound: lynch?.round,
      condemned: lynch?.condemned?.id,
      condemnedMafia: lynch?.role?.team == Team.mafia,
      winner: view.winner,
      iWon: view.winner != null && client.seat != null && view.won(client.seat!.view.seat),
      dayChat: [
        for (final message in client.chat)
          if (message.channel == ChatChannel.day && message.seat != mine) message.at,
      ],
      timeLeft: client.timeLeft,
    );
  }
}

/// Il regista dei meme della partita online: ogni telefono guarda il tavolo
/// pubblico e piazza le battute nei momenti giusti (un voto, un accusato,
/// il verdetto, la piazza che esplode in chat, uno che cade dalla linea).
/// Le pause, le code e le ripetizioni le decide il [MemeBeat].
class MemeDirector {
  MemeDirector({required this.read, required this.beat, required this.clock});

  /// Lo collega a un [GameClient]. Si ferma da solo quando [alive] diventa
  /// falso (lo schermo è chiuso), o con [dispose].
  factory MemeDirector.attach(GameClient client, {required bool Function() alive, MemeBeat? beat}) {
    final director = MemeDirector(
      read: () => MemeSnapshot.of(client),
      beat: beat ?? MemeBeat.instance,
      clock: DateTime.now,
    );
    void listen() => alive() ? director.update() : director.dispose();
    // Senza modalità meme non c'è niente da guardare (e nessun timer).
    if (!director.beat.enabled()) return director;
    client.addListener(listen);
    director._ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => listen());
    director._detach = () => client.removeListener(listen);
    director.update();
    return director;
  }

  final MemeSnapshot Function() read;
  final MemeBeat beat;
  final DateTime Function() clock;

  /// Quanti messaggi in quanto tempo fanno una «raffica».
  static const burstCount = 3;
  static const burstWindow = Duration(seconds: 6);

  MemeSnapshot? _last;
  String? _leader;
  String? _panicked;
  DateTime _lastBurst = DateTime(0);
  Timer? _ticker;
  VoidCallback? _detach;

  void dispose() {
    _ticker?.cancel();
    final detach = _detach;
    _detach = null;
    // Fuori dalla notifica in corso: togliersi mentre si viene chiamati
    // non è permesso.
    if (detach != null) scheduleMicrotask(detach);
  }

  void update() {
    final now = read();
    final before = _last;
    _last = now;
    // Il primo sguardo (o un rientro): si prende nota, non si suona niente.
    // Tranne se la partita comincia proprio adesso.
    if (before == null || before.stage == null) {
      _leader = _leaderOf(now.votes);
      if (before != null && now.stage == Stage.reveal && now.round <= 1) _enter(now, before);
      return;
    }
    final window = '${now.stage?.name}-${now.round}';
    if (now.stage != before.stage || now.round != before.round) _enter(now, before);
    _votes(now, before);
    _chat(now);
    if (now.offline.difference(before.offline).isNotEmpty && now.stage != Stage.ended) beat.hit(MemeMoment.offline);
    // Gli ultimi cinque secondi della piazza o del voto.
    if ((now.stage == Stage.discussion || now.stage == Stage.vote) &&
        now.timeLeft > Duration.zero &&
        now.timeLeft <= const Duration(seconds: 5) &&
        _panicked != window) {
      _panicked = window;
      beat.hit(MemeMoment.timerEnd);
    }
  }

  void _enter(MemeSnapshot now, MemeSnapshot before) {
    switch (now.stage) {
      case Stage.reveal when now.round <= 1:
        beat.hit(MemeMoment.gameStart);
        beat.hit(MemeMoment.roleReveal, after: const Duration(seconds: 3));
      case Stage.dawn when now.dawnRound == now.round:
        if (now.victims == 0) beat.hit(MemeMoment.nobodyDied, after: const Duration(milliseconds: 1200));
        if (now.saves > 0) beat.hit(MemeMoment.save, after: const Duration(milliseconds: 1800));
        if (now.scoopMafia) beat.hit(MemeMoment.scoop, after: const Duration(seconds: 3));
        if (now.silenced) beat.hit(MemeMoment.silenced, after: const Duration(seconds: 5));
      case Stage.vote:
        _leader = null;
        beat.hit(MemeMoment.voteCall);
      case Stage.verdict when now.lynchRound == now.round:
        // La carta stessa ha già la sua battuta (mafioso o innocente):
        // qui resta solo la piazza che non condanna nessuno.
        if (now.condemned == null) beat.hit(MemeMoment.noConviction, after: const Duration(milliseconds: 600));
      case Stage.ended:
        if (now.winner != null) {
          beat.hit(
            now.iWon
                ? MemeMoment.victory
                : now.winner != Team.citizens
                ? MemeMoment.mafiaWins
                : MemeMoment.townWins,
            after: const Duration(milliseconds: 800),
          );
        }
      default:
    }
  }

  void _votes(MemeSnapshot now, MemeSnapshot before) {
    if (now.stage != Stage.vote) return;
    final leader = _leaderOf(now.votes);
    if (leader != null && leader != _leader) {
      _leader = leader;
      beat.hit(MemeMoment.accused);
      return;
    }
    _leader = leader;
    for (final entry in now.votes.entries) {
      if (!before.votes.containsKey(entry.key)) {
        beat.hit(MemeMoment.voteCast);
        return;
      }
      if (before.votes[entry.key] != entry.value) {
        beat.hit(MemeMoment.voteChanged);
        return;
      }
    }
  }

  void _chat(MemeSnapshot now) {
    final at = clock();
    final recent = now.dayChat.where((sent) => at.difference(sent) <= burstWindow).length;
    if (recent >= burstCount && at.difference(_lastBurst) > burstWindow) {
      _lastBurst = at;
      beat.hit(MemeMoment.chatBurst);
    }
  }

  /// Chi ha più voti, se è uno solo.
  static String? _leaderOf(Map<String, String?> votes) {
    final counts = <String, int>{};
    for (final target in votes.values) {
      if (target != null) counts[target] = (counts[target] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final top = counts.values.reduce((a, b) => a > b ? a : b);
    final leaders = [
      for (final entry in counts.entries)
        if (entry.value == top) entry.key,
    ];
    return leaders.length == 1 ? leaders.single : null;
  }
}
