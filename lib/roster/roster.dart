import 'dart:convert';
import 'dart:math';

import '../rules/role_assignment.dart';

/// Quanti possono sedere al tavolo in tutto, eventuale narratore compreso.
const maxTablePlayers = maxRolePlayers;

/// Quante persone tiene l'elenco, sedute o no.
const maxRosterSize = 40;

/// Un nome deve stare su una tessera della griglia.
const maxNameLength = 16;

/// L'inquadratura di partenza di una foto: appena sopra il centro, dove di
/// solito finisce una faccia.
const defaultPhotoX = 0.0;
const defaultPhotoY = -0.2;

/// Perché un nome non si può usare.
enum NameProblem { empty, tooLong, taken }

/// L'elenco ha rifiutato una modifica.
class RosterError implements Exception {
  final String message;

  const RosterError(this.message);

  @override
  String toString() => 'RosterError: $message';
}

/// Una persona dell'elenco: resta salvata anche quando non gioca.
class RosterMember {
  final String id;
  final String name;

  /// La chiave della foto nell'archivio, se ne ha una.
  final String? photo;

  /// Dove cade il centro dell'inquadratura dentro la foto, da -1 a 1.
  final double photoX;
  final double photoY;

  /// Siede al tavolo della prossima partita.
  final bool seated;

  const RosterMember({
    required this.id,
    required this.name,
    this.photo,
    this.photoX = defaultPhotoX,
    this.photoY = defaultPhotoY,
    this.seated = true,
  });

  RosterMember _with({String? name, bool? seated}) => RosterMember(
        id: id,
        name: name ?? this.name,
        photo: photo,
        photoX: photoX,
        photoY: photoY,
        seated: seated ?? this.seated,
      );

  RosterMember _withPhoto(String? photo, double x, double y) => RosterMember(
        id: id,
        name: name,
        photo: photo,
        photoX: photo == null ? defaultPhotoX : x.clamp(-1.0, 1.0),
        photoY: photo == null ? defaultPhotoY : y.clamp(-1.0, 1.0),
        seated: seated,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (photo != null) ...{'photo': photo, 'x': photoX, 'y': photoY},
        'seated': seated,
      };

  /// `null` se la voce non è leggibile: un file rovinato non deve bloccare
  /// il resto dell'elenco.
  static RosterMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final photo = json['photo'];
    final x = json['x'];
    final y = json['y'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return RosterMember(id: id, name: name, seated: json['seated'] == true)._withPhoto(
      photo is String && photo.isNotEmpty ? photo : null,
      x is num ? x.toDouble() : defaultPhotoX,
      y is num ? y.toDouble() : defaultPhotoY,
    );
  }
}

/// L'elenco di chi gioca su questo telefono, e chi di loro siede al tavolo.
/// Non cambia mai: ogni modifica restituisce un elenco nuovo.
class Roster {
  final List<RosterMember> members;

  /// Il numero del prossimo arrivato: gli identificativi non si riusano.
  final int _next;

  Roster._(List<RosterMember> members, this._next) : members = List.unmodifiable(members);

  static final empty = Roster._(const [], 1);

  /// Il nome come viene salvato: senza spazi ai bordi né doppi in mezzo.
  static String cleanName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Due nomi che differiscono solo per le maiuscole sono lo stesso nome.
  static String nameKey(String raw) => cleanName(raw).toLowerCase();

  bool get isEmpty => members.isEmpty;
  bool get isFull => members.length >= maxRosterSize;

  /// Chi siede al tavolo, nell'ordine dell'elenco.
  List<RosterMember> get table => [
        for (final member in members)
          if (member.seated) member,
      ];

  bool get tableIsFull => table.length >= maxTablePlayers;

  RosterMember? byId(String id) {
    for (final member in members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Le chiavi di tutte le foto in uso.
  Set<String> get photos => {
        for (final member in members)
          if (member.photo != null) member.photo!,
      };

  /// Cosa non va in [raw] come nome, oppure `null`. [exceptId] è chi sta
  /// cambiando nome: il suo di adesso non conta come già preso.
  NameProblem? checkName(String raw, {String? exceptId}) {
    final name = cleanName(raw);
    if (name.isEmpty) return NameProblem.empty;
    if (name.runes.length > maxNameLength) return NameProblem.tooLong;
    final key = nameKey(name);
    for (final member in members) {
      if (member.id != exceptId && nameKey(member.name) == key) return NameProblem.taken;
    }
    return null;
  }

  /// Aggiunge una persona in fondo all'elenco. Si siede subito, se c'è posto.
  Roster add(String name, {String? photo, double photoX = defaultPhotoX, double photoY = defaultPhotoY}) {
    final problem = checkName(name);
    if (problem != null) throw RosterError('nome non valido: ${problem.name}');
    if (isFull) throw const RosterError('elenco pieno');
    final member = RosterMember(id: 'p$_next', name: cleanName(name), seated: !tableIsFull)
        ._withPhoto(photo, photoX, photoY);
    return Roster._([...members, member], _next + 1);
  }

  Roster rename(String id, String name) {
    final problem = checkName(name, exceptId: id);
    if (problem != null) throw RosterError('nome non valido: ${problem.name}');
    return _replace(id, (member) => member._with(name: cleanName(name)));
  }

  /// Cambia, sposta o toglie ([photo] `null`) la foto di una persona.
  Roster withPhoto(String id, String? photo, {double x = defaultPhotoX, double y = defaultPhotoY}) =>
      _replace(id, (member) => member._withPhoto(photo, x, y));

  /// Fa sedere o alzare una persona. A tavolo pieno non si siede nessun altro.
  Roster seat(String id, bool seated) {
    final member = byId(id);
    if (member == null || member.seated == seated) return this;
    if (seated && tableIsFull) throw const RosterError('tavolo pieno');
    return _replace(id, (member) => member._with(seated: seated));
  }

  Roster remove(String id) => Roster._([
        for (final member in members)
          if (member.id != id) member,
      ], _next);

  /// Via tutti. Gli identificativi però non ripartono da capo.
  Roster cleared() => Roster._(const [], _next);

  Roster _replace(String id, RosterMember Function(RosterMember) change) => Roster._([
        for (final member in members) member.id == id ? change(member) : member,
      ], _next);

  String encode() => jsonEncode({
        'version': 1,
        'next': _next,
        'people': [for (final member in members) member.toJson()],
      });

  /// Rilegge un elenco salvato. Quello che non torna si scarta, senza mai
  /// fallire: doppioni, nomi impossibili, più gente seduta di quanta ne
  /// regga il tavolo.
  static Roster decode(String? source) {
    if (source == null || source.isEmpty) return empty;
    Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      return empty;
    }
    if (json is! Map) return empty;
    final people = json['people'];
    final next = json['next'];
    var roster = Roster._(const [], next is int && next > 0 ? next : 1);
    final ids = <String>{};
    for (final entry in people is List ? people : const <Object?>[]) {
      final read = RosterMember.fromJson(entry);
      if (read == null || roster.isFull || !ids.add(read.id) || roster.checkName(read.name) != null) continue;
      final member = read._with(name: cleanName(read.name), seated: read.seated && !roster.tableIsFull);
      roster = Roster._([...roster.members, member], max(roster._next, _serialAfter(member.id)));
    }
    return roster;
  }

  static int _serialAfter(String id) {
    final serial = int.tryParse(id.startsWith('p') ? id.substring(1) : '');
    return serial == null ? 1 : serial + 1;
  }
}
