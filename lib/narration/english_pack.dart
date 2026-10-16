import '../rules/game_engine.dart';
import '../rules/role.dart';
import 'death_story.dart';
import 'narration_pack.dart';

// Regole per chi scrive, le stesse del pacchetto italiano più due:
// - breve: una riga o due per battuta, sennò al tavolo nessuno la legge;
// - mai il genere di un giocatore: il nome, "they/their", o si gira la frase;
// - le città e i luoghi sono veri; persone e fatti no;
// - azioni e stacchi devono funzionare in qualsiasi luogo;
// - si gioca passandosi il telefono: nessuno chiude gli occhi;
// - le due fazioni si chiamano sempre "the Family" e "the town";
// - si traduce la battuta, non le parole. Inglese americano.
const englishPack = NarrationPack(
  // I nomi di scena: le battute qui sotto li usano già così ("the Doc").
  roles: {
    Role.mafioso: RoleText(
      'The Soldier',
      '“Nothing personal.”',
      'Each night, with the Family, you pick who won\'t see the dawn.',
    ),
    Role.padrino: RoleText(
      'The Godfather',
      '“I only do favors. Ask around.”',
      'Pick with the Family who won\'t see the dawn. To the Commissioner, you look clean.',
    ),
    Role.sarto: RoleText(
      'The Tailor',
      '“Suits by day. Mouths by night.”',
      'Each night you take someone\'s voice for a day. If the Family runs out of shooters, you shoot.',
    ),
    Role.cittadino: RoleText(
      'The Honest One',
      '“I didn\'t see a thing. Sadly, that\'s true.”',
      'No powers, just eyes and a big mouth. Watch, accuse, vote.',
    ),
    Role.detective: RoleText(
      'The Commissioner',
      '“Everybody lies. Some do it better.”',
      'Each night you investigate someone and find out which side they\'re on.',
    ),
    Role.medico: RoleText(
      'The Doc',
      '“I patch up what others tear open.”',
      'Each night you protect someone. Never the same person two nights running.',
    ),
    Role.cecchino: RoleText(
      'The Sniper',
      '“One shot. Not two.”',
      'You have one bullet for the whole game. Pick your night carefully.',
    ),
    Role.giornalista: RoleText(
      'The Reporter',
      '“The truth hits the stands at six.”',
      'One scoop: at dawn everyone learns which side your pick is on. If you live to see dawn.',
    ),
    Role.becchino: RoleText(
      'The Gravedigger',
      '“My clients never lie.”',
      'Each night you can dig up someone who died at night, and learn, alone, what role they had.',
    ),
    Role.guardaspalle: RoleText(
      'The Bodyguard',
      '“They\'ll have to get through me.”',
      'Each night you shield someone. If they\'re the target that night, you die in their place.',
    ),
    Role.reduce: RoleText(
      'The Veteran',
      '“I\'ve been shot before. By better shots.”',
      'You have thick skin: the first night attack on you misses. The second one doesn\'t.',
    ),
    Role.pregiudicato: RoleText(
      'The Ex-Con',
      '“I did my time. My record didn\'t.”',
      'You\'re with the town, but your record is dirty: to the Commissioner, you look like Family.',
    ),
  },
  cities: [
    CitySetting(
      id: 'chicago',
      name: 'Chicago',
      title: 'Chicago, 1929',
      openings: [
        'Chicago, 1929. Prohibition closed the bars and opened everything else.',
        'Chicago, 1929. The Windy City. It takes your hat, and sometimes whoever\'s under it.',
      ],
      scenes: [
        StoryPiece('chicago-loop', 'Exterior, night. Under the L tracks in the Loop. A train rattles overhead.'),
        StoryPiece('chicago-station', 'Interior, night. Union Station. The waiting room is empty.'),
        StoryPiece('chicago-pier', 'Exterior, night. Navy Pier. Fog on Lake Michigan.'),
        StoryPiece('chicago-jazz', 'Interior, night. The Green Mill: smoke, and a saxophone.'),
        StoryPiece('chicago-bridge', 'Exterior, night. A drawbridge over the Chicago River.'),
        StoryPiece('chicago-market', 'Exterior, night. The Maxwell Street Market, every stall closed.'),
        StoryPiece('chicago-speakeasy', 'Interior, night. A speakeasy on the South Side.'),
        StoryPiece('chicago-hotel', 'Interior, night. The Lexington Hotel lobby. Nobody at the front desk.'),
      ],
    ),
    CitySetting(
      id: 'new-york',
      name: 'New York',
      title: 'New York, 1947',
      openings: [
        'New York, 1947. Eight million people, and not one of them saw a thing.',
        'New York, 1947. The city that never sleeps. Tonight it really ought to try.',
      ],
      scenes: [
        StoryPiece('ny-mulberry', 'Exterior, night. Mulberry Street, Little Italy, under the neon signs.'),
        StoryPiece('ny-bridge', 'Exterior, night. Under the Brooklyn Bridge. Fog on the East River.'),
        StoryPiece('ny-station', 'Interior, night. Grand Central. The clock says three.'),
        StoryPiece('ny-market', 'Exterior, night. The Fulton Fish Market, among the crates.'),
        StoryPiece('ny-coney', 'Exterior, night. Coney Island, off season. The Wonder Wheel stands still.'),
        StoryPiece('ny-pier', 'Exterior, night. A pier on the Hudson. A freighter with no name.'),
        StoryPiece('ny-diner', 'Interior, night. A diner one block from Times Square.'),
        StoryPiece('ny-park', 'Exterior, night. Central Park. One streetlamp still burning.'),
      ],
    ),
    CitySetting(
      id: 'palermo',
      name: 'Palermo',
      title: 'Palermo, 1955',
      openings: [
        'Palermo, 1955. The finest sunshine in the world, and some very long shadows.',
        'Palermo, 1955. Everybody here knows everything. That\'s why nobody says a word.',
      ],
      scenes: [
        StoryPiece('palermo-vucciria', 'Exterior, night. The Vucciria market, shuttered for the night.'),
        StoryPiece('palermo-teatro', 'Exterior, night. The steps of the Teatro Massimo, between the two lions.'),
        StoryPiece('palermo-canti', 'Exterior, night. The Quattro Canti, deserted. Nobody but the statues.'),
        StoryPiece('palermo-cala', 'Exterior, night. La Cala, the old harbor. Boats rocking.'),
        StoryPiece('palermo-ballaro', 'Exterior, night. An alley in Ballarò, laundry on the lines.'),
        StoryPiece('palermo-mondello', 'Exterior, night. Mondello beach, off season.'),
        StoryPiece('palermo-foro', 'Exterior, night. The Foro Italico, on the seafront, among the palms.'),
        StoryPiece('palermo-pasticceria', 'Interior, night. A pastry shop in the historic center, shutters down.'),
      ],
    ),
    CitySetting(
      id: 'napoli',
      name: 'Naples',
      title: 'Naples, 1950',
      openings: [
        'Naples, 1950. Vesuvius smokes, the coffee scalds, and somebody isn\'t sleeping tonight.',
        'Naples, 1950. Everybody here sings. Just never to the cops.',
      ],
      scenes: [
        StoryPiece('napoli-quartieri', 'Exterior, night. An alley in the Spanish Quarter.'),
        StoryPiece('napoli-galleria', 'Interior, night. The Galleria Umberto, empty. Every footstep echoes.'),
        StoryPiece('napoli-molo', 'Exterior, night. The Beverello pier. The ferries aren\'t running.'),
        StoryPiece('napoli-spaccanapoli', 'Exterior, night. Spaccanapoli, straight as a blade.'),
        StoryPiece('napoli-sancarlo', 'Interior, night. The Teatro San Carlo, every seat empty.'),
        StoryPiece('napoli-lungomare', 'Exterior, night. The seafront, below Castel dell\'Ovo.'),
        StoryPiece('napoli-funicolare', 'Interior, night. The Chiaia funicular, last ride of the night.'),
        StoryPiece('napoli-pizzeria', 'Interior, night. A pizzeria on Via dei Tribunali, the oven gone cold.'),
      ],
    ),
    CitySetting(
      id: 'las-vegas',
      name: 'Las Vegas',
      title: 'Las Vegas, 1955',
      openings: [
        'Las Vegas, 1955. A million light bulbs in the desert, to hide everything else.',
        'Las Vegas, 1955. The house always wins. Tonight you find out who the house is.',
      ],
      scenes: [
        StoryPiece('vegas-fremont', 'Exterior, night. Fremont Street: a thousand lights, not one witness.'),
        StoryPiece('vegas-flamingo', 'Interior, night. The casino floor of the Flamingo, in the small hours.'),
        StoryPiece('vegas-desert', 'Exterior, night. The Mojave Desert. Two headlights, one shovel.'),
        StoryPiece('vegas-nugget', 'Interior, night. The back room of the Golden Nugget. A poker table.'),
        StoryPiece('vegas-motel', 'Exterior, night. A motel parking lot on the Strip.'),
        StoryPiece('vegas-dam', 'Exterior, night. Hoover Dam. Below, seven hundred feet of nothing.'),
        StoryPiece('vegas-dressing', 'Interior, night. A singer\'s dressing room, after the show.'),
        StoryPiece('vegas-chapel', 'Interior, night. An all-night wedding chapel.'),
      ],
    ),
  ],
  howToPlay:
      'At night the Family eliminates one person. By day everyone votes on who to eliminate. '
      'The town wins by eliminating the whole Family; the Family wins once it\'s no longer outnumbered.',
  firstNights: [
    'The first night falls on {city}.',
    'Darkness settles over {city}. It\'s the first night.',
    'First night. Sleep well, if your conscience lets you.',
  ],
  nights: [
    'Night falls on {city} once again.',
    'The streetlamps go out. Somebody has work to do.',
    'It\'s night. Somebody has a date. The flowers come later.',
    'Another night. In {city}, folks have started sleeping with their shoes on.',
    'Darkness falls. Even the dogs have stopped barking.',
    'Dead of night. The funeral parlor is working overtime.',
  ],
  nightInstruction: 'Pass the phone around. Everyone makes their move in secret, then passes it on.',
  nobodyDied: 'Nobody died last night.',
  // Per le albe in cui nessuno è stato nemmeno preso di mira. Se il Dottore
  // ha salvato qualcuno lo si vede in scena, e parlano i `rescues`.
  quietDawns: [
    'The funeral parlor expresses its deep concern.',
    'Look around the table: somebody here is disappointed.',
    'Don\'t get comfortable. This is usually how it starts.',
    'The cemetery night watchman slept eight straight hours, and doesn\'t trust it.',
  ],
  secondVictims: [
    'And that\'s not all.',
    'Change of scene.',
    'But it was a long night.',
  ],
  victimFact: 'Last night one person died: {name}. Their role stays secret.',
  // Ogni variante ha il suo filmato: le battute raccontano quello che si vede.
  sniperShots: {
    DeathStory.sniperId: [
      'A single shot, from a faraway window. {name} never heard a thing.',
      'A glint on a rooftop, then a shot. {name} drops before the echo.',
      'Somebody far away took their time aiming. {name} stays on the pavement.',
      'Nobody around the corner this time. Just crosshairs, with {name} dead center.',
    ],
    DeathStory.belfryId: [
      'A glint up in the bell tower. Then a toll, and {name} doesn\'t get up.',
      'The bell strikes the hour and swallows the shot. {name} stays on the cobbles.',
      'A flock of pigeons bursts out of the bell tower. {name} is already down.',
    ],
    DeathStory.phoneBoothId: [
      'The phone booth rings. {name} picks up. The glass cracks into a star.',
      'A hole in the booth\'s glass, a web of cracks. {name} slides down.',
      '{name} lifts the receiver. Nobody speaks on the other end: only the shot.',
    ],
    DeathStory.carDoorId: [
      '{name} opens the car door. A shot from far away: that ride never starts.',
      'Keys in hand, one foot on the running board. Then the shot, and {name} falls.',
      '{name} was about to drive off. The engine stays cold, the door hangs open.',
    ],
  },
  rescues: {
    DeathStory.rescueId: [
      'A shot from the alley, {name} on the ground. Then running footsteps: the Doc.',
      'They came to close {name}\'s account. The Doc got there before the priest.',
      '{name} was already down. But the Doc just happened to be passing by.',
      'One shot, and {name} goes down. A leather bag snaps open: it isn\'t over.',
    ],
    DeathStory.defibrillatorId: [
      '{name} on the ground, heart stopped. The Doc rubs the paddles together: clear!',
      'One jolt, nothing. Another jolt: {name}\'s heart kicks back in.',
      'The Doc opens a box full of wires. One spark, and {name} breathes again.',
    ],
    DeathStory.pliersId: [
      'The Doc digs into {name}\'s wound with a pair of pliers. Out comes the lead.',
      'A bullet in the pliers, a bandage on the chest. {name} is still breathing.',
      '{name} on the ground, the Doc on both knees. “Plink”: the slug hits the tray.',
    ],
    DeathStory.ambulanceId: [
      'A siren down the street. The ambulance slams on the brakes: {name} goes on a stretcher.',
      '{name} on the ground, then the sirens. Stretcher, blanket, and off they race.',
      'The ambulance pulls up, lights flashing. From the stretcher, {name} waves.',
    ],
    DeathStory.stitchesId: [
      'Under the streetlamp, needle and thread. The Doc sews {name} up, stitch by stitch.',
      'Three stitches, a knot, a snip of the scissors. {name} gets back up.',
      'The Doc threads the needle by lamplight. {name} doesn\'t feel a thing.',
    ],
  },
  someone: 'someone',
  savedFact: 'Last night someone got shot, but the Doc made it in time. Who it was stays a secret.',
  // Il colpo andato a vuoto: in scena si vede proprio quello che dice la
  // battuta (la fiaschetta, la Bibbia, la buccia di banana...). Il fatto non
  // nomina nessun ruolo: al tavolo resta il dubbio su chi sia.
  shrugs: {
    DeathStory.luckyId: [
      'A shot. {name} staggers, then pats a breast pocket: a flask, badly dented.',
      'Bang, then “ding.” {name} pulls out a flask with a brand-new hole.',
      'A shot from the alley. {name} stays standing: the bullet is in the flask.',
      '{name} feels a thump in the chest. Under the jacket, a flask bent double.',
    ],
    DeathStory.bibleId: [
      'A shot. {name} pulls a Bible from a breast pocket: the bullet is inside.',
      'The bullet stops in a pocket Bible. {name} looks up and says thanks.',
      '{name} feels a thump in the chest. In the pocket, a Bible holed halfway through.',
    ],
    DeathStory.jamId: [
      'The gun points at {name}. “Click.” Another “click.” The killer takes off running.',
      'The trigger snaps on nothing: the gun has jammed. {name} turns, the killer bolts.',
      '“Click, click.” {name} rolls up both sleeves, and the alley empties out.',
    ],
    DeathStory.bananaId: [
      'The killer steps on a banana peel. The shot goes skyward, and {name} walks away.',
      'A banana peel, a backflip. The shot ends up among the stars: {name} laughs.',
      'The killer charges at {name}, then meets a banana peel. The shot punches the night.',
    ],
    DeathStory.blackCatId: [
      'A black cat leaps onto the killer\'s arm. The shot goes wide, {name} stays standing.',
      'The killer takes aim at {name}. A black cat sends the gun flying.',
      'Bad luck, they say. But tonight a black cat saved {name}.',
    ],
  },
  shruggedFact: 'Last night someone got shot at, but the bullet missed. Who it was stays a secret.',
  methods: [
    StoryPiece('auto', 'Two headlights in the dark. A black sedan doesn\'t brake. {name} turns around: too late.'),
    StoryPiece('pianoforte', 'A rope snaps. A grand piano drops. {name} looks up.'),
    StoryPiece('veleno', '{name} takes the last sip of coffee. Makes a face. Poison.'),
    StoryPiece('pugnale', 'A shadow behind {name}. A blade. Once is enough.'),
    StoryPiece('cemento', 'Two goons hold {name} still. A third one stirs the cement.'),
    StoryPiece('cappio', 'A noose drops out of the dark behind {name}. It tightens.'),
    StoryPiece('silenziatore', 'A muffled pop, like a champagne cork. {name} slides to the ground.'),
    StoryPiece('pacco', '{name} unwraps a present. Inside, something ticks. Then something booms.'),
    StoryPiece('lampadario', 'A creak. A crystal chandelier lets go, right above {name}.'),
    StoryPiece('violino', 'A violin case opens. There is no violin in it. {name} drops.'),
    StoryPiece('cassaforte', 'From above, a safe. {name} has just enough time to read the brand name.'),
    StoryPiece('sigaro', '{name} lights a cigar that came as a gift. The cigar goes “boom.”'),
    StoryPiece('mazza', 'Around the corner, a baseball bat. One swing. {name} sees stars, then nothing.'),
    StoryPiece('lupara', 'Two sawed-off barrels poke out of the dark. A roar. {name} flies backward.'),
    StoryPiece('raffica', 'A car slows. Out the window, a tommy gun. {name} never turns around in time.'),
    StoryPiece('garrota', 'A steel wire, two gloved hands. {name} kicks, then stops.'),
    StoryPiece('vaso', 'A pot of geraniums drops from the third floor. No accident. {name} never sees it.'),
    StoryPiece('tombino', 'A manhole opens under {name}\'s feet. Then it closes again, carefully.'),
    StoryPiece('buio', 'The streetlamp goes dark. A thud. When it comes back, {name} is on the ground.'),
    StoryPiece('bacio', 'A stranger, a kiss, a lipstick to die for. {name} smiles, then does.'),
    StoryPiece('boccia', 'A bowling ball rolls out of the dark. {name} goes flying like a pin. Strike.'),
    StoryPiece('pescespada', 'A swordfish pokes around the corner. En garde, lunge. {name} sleeps with the fishes now.'),
    StoryPiece('arpione', 'A harpoon whistles through the dark and the rope goes taut. {name} vanishes around the corner.'),
    StoryPiece('torta', 'A cream pie, right in {name}\'s face. Everyone laughs. Inside the cream, a grenade.'),
    StoryPiece('trombone', 'A trombone plays in the alley. The bell fires a shot. {name} hits a sour note.'),
    StoryPiece('tango', 'A stranger asks {name} for a tango. A spin, a dip, a dagger.'),
    StoryPiece('rose', 'A bouquet of red roses for {name}. Among the roses, a gun barrel. Petals everywhere.'),
    StoryPiece('lavanderia', 'A laundry van pulls up. A door slides open, two arms. {name} never comes back.'),
  ],
  epilogues: [
    StoryPiece('gatto', 'A cat saw the whole thing. It isn\'t talking.'),
    StoryPiece('mambo', 'Somewhere, a radio is playing a mambo.'),
    StoryPiece('tetti', '{city} sleeps. Or pretends to.'),
    StoryPiece('carta', 'On the ground, a playing card. Roll credits.'),
    StoryPiece('finestra', 'A window lights up, then goes dark.'),
    StoryPiece('sipario', 'The curtain falls. Nobody applauds.'),
    StoryPiece('voce', 'A voice off-screen: “Nothing personal.”'),
    StoryPiece('sirene', 'Sirens in the distance. They\'re always late.'),
    StoryPiece('cappello', 'A hat rolls across the ground. Cut.'),
    StoryPiece('continua', 'On the screen, three words: “To be continued.”'),
  ],
  scoops: [
    'Extra! Extra! {name} is on the front page.',
    'There\'s a line at the newsstand: the paper is all about {name}.',
    'The newsboys are all shouting one name: {name}.',
  ],
  scoopMafia: 'The paper spells it out: {name} is with the Family.',
  scoopClean: 'The paper spells it out: {name} is innocent.',
  silences: [
    'Needle, thread, fine workmanship: this morning {name}\'s lips are stitched shut.',
    'Somebody paid {name} a visit last night. Brought a needle and a word of advice.',
    'On {name}\'s pillow, a spool of black thread. Message received.',
  ],
  silencedFact:
      'Today {name} can\'t talk during the discussion. {name} votes with gestures and can still be eliminated.',
  dayInstruction: 'You have {minutes} to discuss. Then vote on who to eliminate.',
  oneMinute: 'one minute',
  manyMinutes: '{minutes} minutes',
  voteCalls: [
    'Time\'s up. The crowd wants somebody to blame.',
    'Enough talk. {city} wants a name.',
    'The crowd is restless. The executioner is limbering up.',
    'Time to vote. Try not to get it wrong. Again.',
  ],
  voteInstruction: 'Decide out loud who to eliminate. You can also choose to eliminate nobody.',
  lynchScenes: [
    '{name} climbs the steps of the scaffold. The guillotine gleams in the sun.',
    '{name} walks to the noose, head held high. Drumroll.',
    'A freight train, a one-way ticket. {name} is leaving {city}.',
    'The trapdoor at city hall creaks. {name} takes one last look at the crowd.',
    '{name} asks for one last cigarette. The executioner offers a light.',
    'Close-up on {name}\'s tied hands. All of {city} is watching.',
  ],
  cardTurns: 'The card flips. {name} was… {role}.',
  wasMafia: 'On the Family\'s side.',
  wasCitizen: 'On the town\'s side.',
  lynchedInnocent: [
    'Nice work, everybody. Really.',
    'Somebody at this table is trying not to smile.',
    'The Family thanks you for your cooperation.',
    'The executioner apologizes, and charges full price anyway.',
  ],
  lynchedMafioso: [
    'One down. But this one had friends, and friends have long memories.',
    'Somebody just lost a partner, and can\'t even go to the funeral.',
    'Nice shot. Tonight the Family will be in a foul mood.',
  ],
  lynchedLastMafioso: [
    'And that was the last of them. Every bell in the city is ringing.',
    'That was the last one. In {city}, at long last, somebody talked.',
  ],
  noLynch: [
    'The executioner gets home early, for once.',
    'Somebody breathes a sigh of relief. Wonder who.',
    'In {city}, not agreeing on anything is business as usual.',
  ],
  noLynchFact: 'Nobody is eliminated today.',
  citizensWin: [
    '{city} is free. Starting tomorrow, people sleep with the windows open. Roll credits.',
    'On the street, people look each other in the eye again. On screen: “The End.”',
  ],
  citizensWinFact: 'The town wins: the whole Family has been eliminated.',
  mafiaWins: [
    '{city} has new bosses, and they were sitting right at this table. Roll credits.',
    'In {city}, nobody saw a thing. As usual. Fade to black.',
  ],
  mafiaWinsFact: 'The Family wins: the town no longer outnumbers them.',
  taskPrompts: {
    NightTaskKind.kill: 'Who does the Family eliminate tonight?',
    NightTaskKind.silence: 'Whose lips do you sew shut tonight?',
    NightTaskKind.protect: 'Who do you protect tonight?',
    NightTaskKind.guard: 'Who do you shield tonight?',
    NightTaskKind.investigate: 'Who do you want to investigate?',
    NightTaskKind.dig: 'Whose grave do you dig up tonight?',
    NightTaskKind.snipe: 'Do you want to shoot somebody?',
    NightTaskKind.scoop: 'Who is your scoop about?',
  },
  taskHints: {
    NightTaskKind.kill: 'Whoever you pick won\'t see the dawn. If there are several of you, majority rules.',
    NightTaskKind.silence: 'Whoever you pick can\'t talk tomorrow. Never the same person two nights in a row.',
    NightTaskKind.protect: 'Whoever you pick can\'t die tonight. Never the same person two nights in a row.',
    NightTaskKind.guard: 'If somebody tries to kill your pick tonight, you die in their place.',
    NightTaskKind.investigate: 'You\'ll find out right away whether they\'re with the Family or the town.',
    NightTaskKind.dig: 'Pick someone who died at night. You, and only you, learn their role at once.',
    NightTaskKind.snipe: 'You have one bullet for the whole game. If you pass, you keep it.',
    NightTaskKind.scoop: 'You have one scoop: at dawn everyone learns your pick\'s side. Pass, and you keep it.',
    NightTaskKind.decoy: 'You have no move tonight: answer anyway, so nobody can tell who you are.',
  },
  decoyPrompts: [
    'Who looks the most suspicious to you?',
    'Who would you never trust?',
    'Who has the face of somebody with something to hide?',
    'If you had to point a finger, who would it be?',
    'Who is putting on the best act at this table?',
  ],
);
