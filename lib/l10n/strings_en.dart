import '../narration/english_pack.dart';
import '../narration/narration_pack.dart';
import '../ui/widgets/death_scene.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// L'interfaccia in inglese americano. Le stesse regole del copione: mai il
/// genere di un giocatore ("they"), nessuno chiude gli occhi, le fazioni
/// sono "the Family" e "the town".
final class EnglishStrings extends AppStrings {
  const EnglishStrings();

  @override
  AppLanguage get language => AppLanguage.en;

  @override
  NarrationPack get pack => englishPack;

  @override
  String get settings => 'Settings';
  @override
  String get alleyPlaque => 'HUSH ALLEY';
  @override
  String get tonight => 'TONIGHT ONLY';
  @override
  String get sharedTitle => 'ONE PHONE FOR ALL';
  @override
  String get sharedBlurb => 'Pass it from hand to hand. No network, no witnesses.';
  @override
  String get createRoom => 'CREATE ROOM';
  @override
  String get hostName => 'You';
  @override
  String get soon => 'COMING SOON';
  @override
  String get ownTitle => 'ONE PHONE\nEACH';
  @override
  String get ownBlurb => 'Everyone on their own phone, and a four-letter code.';
  @override
  String get ownTeaser => 'One phone each needs the network. Sit tight.';
  @override
  String get rankedTitle => 'RANKED';
  @override
  String get rankedBlurb => 'Strangers, points, and a leaderboard to climb.';
  @override
  String get rankedTeaser => 'Ranked opens soon. Meanwhile, make a name for yourself.';
  @override
  List<String> get homeCaptions => const [
        'Nobody saw a thing.',
        'Nobody talks. Somebody dies.',
        'You weren\'t there. And if you were, you were asleep.',
        'In this town even the walls keep quiet.',
        'Trust is good. Silence is better.',
        'Those who know keep quiet. Those who talk miss the sunrise.',
        'Tonight somebody doesn\'t make it home.',
      ];

  @override
  String get settingsTitle => 'SETTINGS';
  @override
  String get sound => 'Music and sound effects';
  @override
  String get soundHint => 'You\'ll hear them even with the phone on silent.';
  @override
  String get languageSetting => 'Language';
  @override
  String get languageAutomatic => 'Automatic (phone)';
  @override
  String get rehearsal => 'Screening room';
  @override
  String get rehearsalHint => 'Rewatch the night\'s scenes, one at a time.';

  @override
  String get narratorTitle => 'NARRATOR';
  @override
  String get whoPullsTheStrings => 'Who pulls\nthe strings?';
  @override
  String get narratorIntro => 'The narrator runs the game and knows every role.';
  @override
  String get pickedByGroup => 'Picked by the group';
  @override
  String get pickedByGroupHint => 'You decide who tells the story. They don\'t get a role.';
  @override
  String get drawnByCylinder => 'Drawn from the cylinder';
  @override
  String get drawnByCylinderHint => 'One spin of the cylinder. Whoever comes up narrates and sits out.';
  @override
  String get automaticNarrator => 'Automatic narrator';
  @override
  String get automaticNarratorHint => 'The phone tells the story: everybody plays.';
  @override
  String needAtLeast(int players) => 'You need at least $players players';
  @override
  String get whoNarrates => 'WHO NARRATES?';
  @override
  String get drawTitle => 'THE DRAW';
  @override
  String get whoNarratesTonight => 'Who narrates\ntonight?';
  @override
  String get theNarratorIs => 'THE NARRATOR IS';
  @override
  String get continueLabel => 'CONTINUE';

  @override
  String get cardsTitle => 'THE CARDS';
  @override
  String get automatic => 'Automatic';
  @override
  String get cardsDealt => 'The cards are dealt';
  @override
  String get shuffling => 'Shuffling the deck…';
  @override
  String get checkYourCards => 'CHECK YOUR CARDS';
  @override
  String cardOf(int card, int of) => 'CARD $card OF $of';
  @override
  String get holdTheCardHint => 'Press and hold the card to look.\nLet go and it flips back.';
  @override
  String get gotIt => 'GOT IT';
  @override
  String get pressAndHold => 'PRESS AND HOLD';
  @override
  String get youAreFamily => 'YOU\'RE WITH THE FAMILY';
  @override
  String get youAreTown => 'YOU\'RE WITH THE TOWN';
  @override
  String get youActAlone => 'YOU WORK ALONE';
  @override
  String get yourAccomplices => 'YOUR ACCOMPLICES';
  @override
  String get familyBadge => 'FAMILY';
  @override
  String get townBadge => 'TOWN';

  @override
  String get passThePhoneTo => 'PASS THE PHONE TO';
  @override
  String get nobodyElseLooks => 'Nobody else looks at the screen.';
  @override
  String get itsMe => 'IT\'S ME';
  @override
  String get youBadge => 'YOU';
  @override
  String get innocentBadge => 'INNOCENT';
  @override
  String get readAloud => 'READ IT OUT LOUD';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} READS IT OUT LOUD';
  @override
  String get narratorOnly => 'NARRATOR ONLY';
  @override
  String get holdToSeeRoles => 'Press and hold to see every role';

  @override
  String nightTitle(int round) => 'NIGHT $round';
  @override
  String get nightFalls => 'Night falls';
  @override
  String get startTheNight => 'START THE NIGHT';
  @override
  String get dawnTitle => 'DAWN';
  @override
  String get everyoneAlive => 'Everyone made it';
  @override
  String get crimePage => 'The crime page';
  @override
  String get finale => 'THE FINALE';
  @override
  String get openTheFloor => 'OPEN THE FLOOR';
  @override
  String dayTitle(int round) => 'DAY $round';
  @override
  String get verdictTitle => 'THE VERDICT';
  @override
  String get noConviction => 'No conviction';
  @override
  String get endTitle => 'THE END';
  @override
  String get leaveQuestion => 'Walk out on the game?';
  @override
  String get leaveWarning => 'The game in progress will be lost.';
  @override
  String get stay => 'STAY';
  @override
  String get leave => 'LEAVE';
  @override
  String get leaveTooltip => 'Leave the game';
  @override
  String get rolesTooltip => 'Roles, for the narrator only';
  @override
  String get phoneOnTheTable => 'Phone\non the table';
  @override
  String get phoneOnTheTableHint => 'Put it in the middle where everyone can see.\nSomething happened last night.';
  @override
  String get lightsDown => 'LIGHTS DOWN';
  @override
  String get pass => 'PASS';
  @override
  String get confirm => 'CONFIRM';
  @override
  String get doneTitle => 'Done.';
  @override
  String get nobodyWillKnow => 'Nobody will know what you chose.';
  @override
  String get yourInvestigation => 'YOUR INVESTIGATION';
  @override
  String get inTheGrave => 'IN THE GRAVE';
  @override
  String wasRole(String role) => 'WAS ${role.toUpperCase()}';
  @override
  String get isFamily => 'IS WITH THE FAMILY';
  @override
  String get isInnocent => 'IS INNOCENT';
  @override
  String get wasWithFamily => 'WAS WITH THE FAMILY';
  @override
  String get wasWithTown => 'WAS WITH THE TOWN';
  @override
  String get done => 'DONE';
  @override
  String get nobody => 'NOBODY';
  @override
  String get condemn => 'CONDEMN';
  @override
  String fateNight(int round) => 'Night $round';
  @override
  String fateGallows(int round) => 'Gallows, day $round';
  @override
  String get stillStanding => 'Still standing';
  @override
  String get familyWins => 'The Family\nwins';
  @override
  String get townWins => 'The town\nwins';
  @override
  String get whoWasWho => 'WHO WAS WHO';
  @override
  String get mostSuspicious => 'THE SHADIEST FACE';
  @override
  String suspicion(String name, int fingers, {required bool rightly}) =>
      '$name, with $fingers ${fingers == 1 ? 'finger' : 'fingers'} pointed in the dark. '
      '${rightly ? 'Rightly so.' : 'Wrongly, as it turns out.'}';
  @override
  String get backHome => 'BACK TO THE ALLEY';
  @override
  String get keepReading => 'KEEP READING';
  @override
  String get flipTheCard => 'FLIP THE CARD';
  @override
  String get timeUp => 'TIME\'S UP';
  @override
  String get floorIsOpen => 'THE FLOOR IS OPEN';
  @override
  String get plusMinute => '+1 MIN';
  @override
  String get callTheVote => 'CALL THE VOTE';

  @override
  String get willSeeDawn => 'WILL SEE THE DAWN';
  @override
  String get wontSeeDawn => 'WON\'T SEE THE DAWN';
  @override
  String get next => 'NEXT';
  @override
  String get skip => 'SKIP';

  @override
  String get screeningTitle => 'SCREENING ROOM';
  @override
  String get screeningIntro => 'Every scene of the night. Tap one to watch it again.';
  @override
  String get screeningCaption => 'Exterior, night. Dress rehearsal.';
  @override
  String sceneName(DeathAct act) => switch (act) {
        DeathAct.knife => 'The dagger',
        DeathAct.gun => 'The silencer',
        DeathAct.burst => 'The violin case',
        DeathAct.car => 'The black sedan',
        DeathAct.piano => 'The grand piano',
        DeathAct.safe => 'The safe',
        DeathAct.chandelier => 'The chandelier',
        DeathAct.blast => 'The gift box',
        DeathAct.poison => 'The spiked coffee',
        DeathAct.noose => 'The noose',
        DeathAct.grab => 'The cement shoes',
        DeathAct.bat => 'The baseball bat',
        DeathAct.lupara => 'The sawed-off shotgun',
        DeathAct.driveBy => 'The drive-by',
        DeathAct.garrote => 'The garrote',
        DeathAct.pot => 'The flowerpot from the third floor',
        DeathAct.manhole => 'The manhole',
        DeathAct.blackout => 'The blackout',
        DeathAct.kiss => 'The kiss',
        DeathAct.sniper => 'The Sniper',
        DeathAct.rescue => 'The Doc arrives in time',
        DeathAct.lucky => 'The flask',
      };
}
