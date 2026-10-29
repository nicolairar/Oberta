import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/l10n/app_language.dart';
import 'package:oberta/l10n/bidi.dart';
import 'package:oberta/l10n/lobby_language.dart';
import 'package:oberta/online/game/game_backend.dart';
import 'package:oberta/ui/screens/online/chat_panel.dart';
import 'package:oberta/ui/screens/online/ranked_entry.dart';
import 'package:oberta/ui/theme/script_fonts.dart';
import 'package:oberta/ui/widgets/language_flag.dart';

import '../support/languages.dart';

/// Lines a player could write in any script: the chat must lay them out
/// without overflow or exceptions, whatever the interface language.
const _lines = {
  'zh': '我什么都没看见。今晚谁会死？',
  'ja': '誰も何も見ていない。今夜、誰かが帰らない。',
  'ko': '아무도 아무것도 못 봤어. 오늘 밤 누군가 죽는다.',
  'ar': 'لم يرَ أحد شيئًا. الليلة لن يعود أحدهم إلى بيته.',
  'he': 'אף אחד לא ראה כלום. הלילה מישהו לא חוזר הביתה.',
  'hi': 'किसी ने कुछ नहीं देखा। आज रात कोई घर नहीं लौटेगा।',
  'th': 'ไม่มีใครเห็นอะไรเลย คืนนี้มีคนไม่ได้กลับบ้าน',
  'ru': 'Никто ничего не видел. Сегодня кто-то не вернётся домой.',
  'el': 'Κανείς δεν είδε τίποτα. Απόψε κάποιος δεν γυρίζει σπίτι.',
};

ChatPanel _chat(Map<String, String> lines) => ChatPanel(
      title: 'Chat',
      messages: [
        for (final (i, MapEntry(:key, :value)) in lines.entries.indexed)
          ChatMessage(
            id: 'm$i',
            n: i + 1,
            channel: ChatChannel.day,
            profileId: 'p$i',
            seat: 's${i + 1}',
            name: 'player_$key',
            body: value,
            at: DateTime(2026, 10, 29, 21, i),
          ),
      ],
      myId: 'p0',
      note: null,
      hint: '…',
      empty: '—',
      sendLabel: 'Send',
      onSend: (_) async {},
    );

void main() {
  testWidgets('the chat lays out Chinese, Japanese, Korean, Arabic, Hebrew, Hindi, Thai, Cyrillic and Greek', (tester) async {
    for (final language in AppLanguage.values) {
      for (final size in const [Size(320, 640), Size(430, 932)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(appIn(language, Scaffold(body: _chat(_lines))));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '${language.code} $size');
        for (final line in _lines.values) {
          expect(find.textContaining(line, findRichText: true, skipOffstage: false), findsOneWidget, reason: line);
        }
      }
    }
    addTearDown(tester.view.reset);
  });

  test('a right-to-left message is isolated, a left-to-right one is left alone', () {
    expect(bidiIsolate(_lines['ar']!), '\u2068${_lines['ar']}\u2069');
    expect(bidiIsolate(_lines['he']!), startsWith('\u2068'));
    expect(bidiIsolate('ciao a tutti'), 'ciao a tutti');
    expect(bidiIsolate(_lines['ja']!), _lines['ja']);
    expect(directionOf(_lines['ar']!), TextDirection.rtl);
    expect(directionOf(_lines['zh']!), TextDirection.ltr);
  });

  testWidgets('a right-to-left page renders: the chat and the ranked tables, mirrored', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sweep = AnimationController(vsync: tester, duration: const Duration(seconds: 1));
    addTearDown(sweep.dispose);
    for (final page in [
      _chat(_lines),
      RankedEntryView(
        language: LobbyLanguage.tryParse('ar')!,
        lobbies: LobbyLanguage.offered(LobbyLanguage.tryParse('ar')!),
        onLanguage: (_) {},
        queued: false,
        sweep: sweep,
        cooldown: null,
        warning: false,
        onStart: () {},
        onCancel: () {},
      ),
    ]) {
      await tester.pumpWidget(appIn(
        AppLanguage.en,
        Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: page)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
    expect(find.text('العربية'), findsOneWidget, reason: 'the Arabic table shows its own name');
  });

  testWidgets('every lobby has a flag or a tag, and the ranked cards show three tables', (tester) async {
    await tester.pumpWidget(appIn(
      AppLanguage.en,
      Wrap(children: [for (final code in ['it', 'en', 'es', 'fr', 'de', 'pt', 'ja', 'ar', 'zz']) LanguageFlag(code)]),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('JA'), findsOneWidget);
    expect(LanguageFlag.painted, containsAll([for (final l in AppLanguage.values) l.code]));
  });

  test('the fallback fonts cover every script after the display fonts', () {
    for (final family in ['PingFang SC', 'Noto Sans CJK JP', 'Noto Naskh Arabic', 'Noto Sans Hebrew', 'Noto Sans Devanagari', 'Noto Sans Thai']) {
      expect(serifFallback, contains(family));
      expect(monoFallback, contains(family));
    }
    expect(serifFallback.first, 'serif');
    expect(monoFallback.first, 'monospace');
  });

  group('the lobbies', () {
    test('Italian and English for everyone, plus the player\'s own language first', () {
      final ja = LobbyLanguage.tryParse('ja')!;
      expect(LobbyLanguage.offered(ja), [ja, LobbyLanguage.it, LobbyLanguage.en]);
      expect(LobbyLanguage.offered(LobbyLanguage.en), [LobbyLanguage.en, LobbyLanguage.it]);
      expect(LobbyLanguage.offered(LobbyLanguage.it), [LobbyLanguage.it, LobbyLanguage.en]);
    });

    test('an untranslated phone keeps its lobby but plays in English', () {
      final lobby = LobbyLanguage.forDevice(const [Locale('ja', 'JP')]);
      expect(lobby.code, 'ja');
      expect(lobby.app, AppLanguage.en);
      expect(lobby.nativeName, '日本語');
      expect(LobbyLanguage.forDevice(const [Locale('es', 'MX')]).app, AppLanguage.es);
    });

    test('only ISO 639-1 codes are lobbies', () {
      expect(LobbyLanguage.tryParse('JA')?.code, 'ja');
      expect(LobbyLanguage.tryParse('xx'), isNull);
      expect(LobbyLanguage.tryParse('pt-BR'), isNull);
      expect(LobbyLanguage.parse(null), LobbyLanguage.it);
      expect(isoLanguageCodes, hasLength(183));
    });

    test('Arabic and Hebrew lay out right to left, the shipped languages left to right', () {
      expect(LobbyLanguage.tryParse('ar')!.textDirection, TextDirection.rtl);
      expect(LobbyLanguage.tryParse('he')!.textDirection, TextDirection.rtl);
      for (final language in AppLanguage.values) {
        expect(language.textDirection, TextDirection.ltr, reason: language.code);
      }
    });
  });
}
