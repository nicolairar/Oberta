import 'dart:math';

import '../ui/widgets/death_scene.dart';

/// La modalità meme: i suoni dei meme al posto (o sopra) di quelli seri,
/// nei momenti pubblici della partita. Mai in quelli privati: un meme
/// che parte mentre il Commissario indaga lo sentirebbero tutti.
///
/// I file vengono da internet e non sono nostri: per ora la modalità è solo
/// per le build di prova, spenta di default.
enum Meme {
  vineBoom,
  faaah,
  animeAhh,
  animeGirl,
  lutador,
  catLaugh,
  chicken,
  heeHee,
  rizz,
  hellNah,
  englishSpanish,
  dexter,
  applePay,
  error,
  knocked,
  auraFarming,
  fridayDamn,
  rizzLove;

  /// Quanto dura, in millisecondi: quelli lunghi (le canzoncine, la risata)
  /// zittiscono la musica finché non finiscono.
  int get millis => switch (this) {
        vineBoom => 1175,
        faaah => 1810,
        animeAhh => 570,
        animeGirl => 1890,
        lutador => 6430,
        catLaugh => 3250,
        chicken => 5380,
        heeHee => 930,
        rizz => 1270,
        hellNah => 9840,
        englishSpanish => 24470,
        dexter => 10550,
        applePay => 630,
        error => 790,
        knocked => 650,
        auraFarming => 12420,
        fridayDamn => 3740,
        rizzLove => 1930,
      };

  /// Una canzoncina o una risata lunga: sopra la tarantella non si capisce
  /// niente, quindi la musica tace.
  bool get isLong => millis > 2500;

  String get asset => 'meme/${switch (this) {
        vineBoom => 'vine_boom',
        animeAhh => 'anime_ahh',
        animeGirl => 'anime_girl',
        catLaugh => 'cat_laugh',
        heeHee => 'hee_hee',
        hellNah => 'hell_nah',
        englishSpanish => 'english_spanish',
        applePay => 'applepay',
        auraFarming => 'aura_farming',
        fridayDamn => 'friday_damn',
        rizzLove => 'rizz_love',
        _ => name,
      }}.m4a';
}

final _dice = Random();

Meme _one(List<Meme> memes) => memes[_dice.nextInt(memes.length)];

/// Il meme sul colpo di una scena, se ce n'è uno (non sempre: stufa).
Meme? strikeMeme(DeathAct act) => switch (act) {
      DeathAct.kiss => _one(const [Meme.rizz, Meme.heeHee]),
      DeathAct.rescue => Meme.applePay,
      DeathAct.lucky => null,
      _ when act.survives => null,
      _ => _dice.nextDouble() < 0.8 ? _one(const [Meme.knocked, Meme.knocked, Meme.vineBoom]) : null,
    };

/// Il meme della reazione, un attimo dopo il colpo.
Meme? reactionMeme(DeathAct act) => switch (act) {
      DeathAct.kiss => _one(const [Meme.animeAhh, Meme.animeGirl]),
      DeathAct.manhole => Meme.lutador,
      DeathAct.rescue || DeathAct.lucky => null,
      _ when act.survives => null,
      // Qualcuno è morto davvero: o il «faaah», o il «damn».
      _ => _dice.nextDouble() < 0.9 ? _one(const [Meme.faaah, Meme.fridayDamn]) : null,
    };

/// I meme brevi e stupidi, quelli che si possono buttare ovunque.
const shortMemes = [Meme.vineBoom, Meme.knocked, Meme.heeHee, Meme.rizz, Meme.animeAhh, Meme.applePay, Meme.error];

/// Un meme breve a caso, con probabilità [chance]: per i momenti qualsiasi
/// (una carta che cade, un posto preso) che diventano cringe.
Meme? now(double chance, [List<Meme> pool = shortMemes]) => _dice.nextDouble() < chance ? _one(pool) : null;

/// La carta girata dopo il verdetto.
Meme cardMeme({required bool caught}) => caught ? Meme.vineBoom : _one(const [Meme.catLaugh, Meme.hellNah]);
