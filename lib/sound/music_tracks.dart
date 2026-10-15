import 'sound_stage.dart';

/// Le tracce di sottofondo di ogni momento (in `assets/music/`). Se un
/// momento ne ha più d'una, a ogni cambio ne esce una a caso.
const musicTracks = {
  MusicMood.menu: ['menu', 'menu_2'],
  MusicMood.night: ['night', 'night_2'],
  MusicMood.day: ['day', 'day_2'],
  MusicMood.winTown: ['win_town', 'win_town_2'],
  MusicMood.winFamily: ['win_family', 'win_family_2'],
};
