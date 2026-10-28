import '../narration/english_pack.dart';
import '../narration/narration_pack.dart';
import '../roster/roster.dart';
import '../ui/widgets/verdict_scene.dart';
import 'app_language.dart';
import 'app_strings.dart';
import 'online_strings.dart';
import 'shop_strings.dart';

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
  OnlineStrings get online => const EnglishOnlineStrings();
  @override
  ShopStrings get shop => const EnglishShopStrings();

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
  String get neutralBadge => 'NEUTRAL';
  @override
  String get youAreNeutral => 'YOU PLAY FOR YOURSELF';
  @override
  String get arsonistWins => 'A lone wolf\nwins';
  @override
  String get wonAlone => 'WON ALONE';
  @override
  String get revealAsMayor => 'Reveal yourself: Mayor';
  @override
  String get lightTheMatch => 'Light the match';
  @override
  String get dousePick => 'Douse';
  @override
  String get dousedBadge => 'GASOLINE';
  @override
  String get bountyBadge => 'BOUNTY';
  @override
  String get bountyLine => 'You have a bounty on {name}: get the town to lynch them.';
  @override
  String get readAloud => 'READ IT OUT LOUD';
  @override
  String readerReadsAloud(String reader) => '${reader.toUpperCase()} READS IT OUT LOUD';
  @override
  String get narratorSpeaks => 'THE NARRATOR SPEAKS';
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
  String get dayBreaks => 'Day breaks';
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
  String get voteTheHit => 'THE HIT';
  @override
  String get sewAMouth => 'SEW A MOUTH';
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
  String wasRole(String role) => 'WAS THE ${role.toUpperCase()}';
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
  String get accusedStamp => 'ACCUSED';
  @override
  String aliveCount(int alive, int total) => '$alive of $total still standing';

  @override
  String get willSeeDawn => 'WILL SEE THE DAWN';
  @override
  String get wontSeeDawn => 'WON\'T SEE THE DAWN';
  @override
  String get next => 'NEXT';
  @override
  String get skip => 'SKIP';

  @override
  String verdictCaption(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'Sundown, down at the docks.',
    VerdictTake.cartello => 'The city limits. A dusty road, and no ride back.',
    VerdictTake.treno => 'Central Station. The last train out tonight.',
    VerdictTake.cannone => 'The circus has come to the city. Volunteer wanted.',
    VerdictTake.assoluzione => 'The main square at sundown. Tempers flare.',
  };
  @override
  String verdictStamp(VerdictTake take) => switch (take) {
    VerdictTake.molo => 'SLEEPS WITH THE FISHES',
    VerdictTake.cartello => 'RUN OUT OF THE CITY',
    VerdictTake.treno => 'ONE WAY TICKET',
    VerdictTake.cannone => 'IN ORBIT',
    VerdictTake.assoluzione => '',
  };
  @override
  String get verdictLine => 'THE PEOPLE HAVE SPOKEN';
  @override
  String get acquittalTitle => 'NO CONVICTION';
  @override
  String get acquittalLine => 'EVERYBODY GO HOME. FOR TONIGHT.';
  @override
  String get townSign => 'CITY';
  @override
  String verdictWord(VerdictWord word) => switch (word) {
    VerdictWord.thud => 'THUNK!',
    VerdictWord.byeBye => 'BYE BYE!',
    VerdictWord.glub => 'GLUB',
    VerdictWord.getOut => 'GET OUT!',
    VerdictWord.cough => 'COUGH!',
    VerdictWord.toot => 'CHOO-CHOO!',
    VerdictWord.sniff => 'SNIFF!',
    VerdictWord.ping => 'TWINKLE!',
    VerdictWord.bonk => 'BONK!',
    VerdictWord.shrug => 'MEH!',
  };

  @override
  String get lobbyTitle => 'THE TABLE';

  @override
  String get lobbyDebugAdd => '+ TEST';

  @override
  String get lobbyClearTooltip => 'Clear everyone';

  @override
  String get lobbyEmptyTitle => 'WHO\'S PLAYING TONIGHT?';

  @override
  String get lobbyEmptyBody => 'Pass the phone around: everyone types their name and takes a mugshot.';

  @override
  String get lobbyEmptyPlaceholder => '???';

  @override
  String get lobbyTableEmpty => 'EMPTY TABLE';

  @override
  String get lobbyReadyHint => 'Ready when you are.';

  @override
  String get lobbyTableFull => 'Table full: no more than $maxTablePlayers players.';

  @override
  String get lobbyTableFullRefusal => 'The table is full: someone has to stand up first.';

  @override
  String get lobbyRosterFull => 'The list is full: remove someone first.';

  @override
  String get lobbyGestureHint => 'Tap a face to seat or unseat them.\nPress and hold to change the name or photo.';

  @override
  String get lobbyOut => 'OUT';

  @override
  String get lobbyPrivacy => 'Names and photos stay on this phone.';

  @override
  String get lobbyAdd => 'ADD';

  @override
  String get lobbyStart => 'START';

  @override
  String get lobbyClearTitle => 'Clear everyone?';

  @override
  String get lobbyClearBody => 'This deletes every name and photo from this phone. There is no undo.';

  @override
  String get lobbyClearCancel => 'CANCEL';

  @override
  String get lobbyClearConfirm => 'DELETE ALL';

  @override
  String lobbySeated(int seated) => '$seated AT THE TABLE';

  @override
  String lobbyMissing(int missing) => missing == 1 ? 'One more player to start.' : '$missing more players to start.';

  @override
  String get personTitleNew => 'NEW FILE';

  @override
  String get personTitleEdit => 'FILE';

  @override
  String get personPlacardEmpty => 'YOUR NAME';

  @override
  String get personNameHint => 'What\'s your name?';

  @override
  String get personNameEmpty => 'No name, no file.';

  @override
  String get personNameTooLong => 'Too long: $maxNameLength letters at most.';

  @override
  String get personNameTaken => 'Someone already goes by that name.';

  @override
  String get personShoot => 'SHOOT';

  @override
  String get personReshoot => 'RETAKE';

  @override
  String get personGallery => 'GALLERY';

  @override
  String get personNoPhoto => 'NO PHOTO';

  @override
  String get personHintDrag => 'Drag to center the face';

  @override
  String get personSubmitNew => 'ADD TO THE TABLE';

  @override
  String get personSubmitEdit => 'SAVE';

  @override
  String get personPrivacy => 'The photo stays on this phone: the game never sends it anywhere.';

  @override
  String get personCameraDenied => 'No camera permission. You can allow it in Settings, or play without a photo.';

  @override
  String get personCameraFailed => 'The photo didn\'t work. Try again, or play without one.';

  @override
  String get personStamp => 'BOOKED';

  @override
  String get personBookedPass => 'Pass the phone to the next one.';

  @override
  String get personNext => 'NEXT!';

  @override
  String get personDone => 'WE\'RE DONE';

  @override
  String get personRemoveTooltip => 'Remove from the list';

  @override
  String get personRemoveCancel => 'CANCEL';

  @override
  String get personRemoveConfirm => 'REMOVE';

  @override
  String get personRemoveBody => 'This deletes the name and photo from the phone.';

  @override
  String personBookedSeated(String name) => '$name is at the table.';

  @override
  String personBookedWatching(String name) => 'The table is full: $name watches for now.';

  @override
  String personRemoveTitle(String name) => 'Remove $name?';

  @override
  String verdictName(VerdictTake take) => switch (take) {
        VerdictTake.molo => 'The pier',
        VerdictTake.cartello => 'The city limits',
        VerdictTake.treno => 'The last train',
        VerdictTake.cannone => 'The circus cannon',
        VerdictTake.assoluzione => 'No conviction',
      };

  @override
  String get someoneSaved => 'SOMEONE';

  @override
  String get musicVolumeLabel => 'Music';

  @override
  String get effectsVolumeLabel => 'Sound effects';

  @override
  String get memeMode => 'Meme mode';

  @override
  String get memeModeHint => 'Vine booms, FAAAH and friends at the big moments.';
}
