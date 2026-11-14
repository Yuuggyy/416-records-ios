import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';

/// Morceau du catalogue. Le backend renvoie aussi `artiste_slug` et
/// `artiste_nom` : ils sont conservés pour afficher la fiche artiste sans
/// requête supplémentaire.
class Morceau extends Equatable {
  const Morceau({
    required this.id,
    required this.titre,
    this.dureeSecondes,
    this.annee,
    this.spotifyUrl,
    this.youtubeUrl,
    this.appleMusicUrl,
    this.deezerUrl,
    this.audiomackUrl,
    this.audioUrl,
    this.audioHqUrl,
    this.posterUrl,
    this.paroles,
    this.premium = false,
    this.artisteSlug = '',
    this.artisteNom = '',
  });

  final int id;
  final String titre;
  final int? dureeSecondes;
  final int? annee;
  final String? spotifyUrl;
  final String? youtubeUrl;
  final String? appleMusicUrl;
  final String? deezerUrl;
  final String? audiomackUrl;
  final String? audioUrl;

  /// Écoute « super fan » (WAV/FLAC) ; `audioUrl` est la version compressée.
  final String? audioHqUrl;
  final String? posterUrl;

  /// Texte simple ou LRC (`[mm:ss.cc] ligne`) ; voir `core/paroles.dart`.
  final String? paroles;
  final bool premium;
  final String artisteSlug;
  final String artisteNom;

  /// Durée au format `m:ss` (ou `h:mm:ss` au-delà d'une heure).
  String get dureeLisible {
    final secondes = dureeSecondes;
    if (secondes == null || secondes <= 0) return '—';
    final minutes = secondes ~/ 60;
    final reste = secondes % 60;
    return '$minutes:${reste.toString().padLeft(2, '0')}';
  }

  factory Morceau.depuisJson(Map<String, dynamic> json) {
    return Morceau(
      id: entier(json['id']),
      titre: texte(json['titre']),
      dureeSecondes: entierOuNull(json['duree_secondes']),
      annee: entierOuNull(json['annee']),
      spotifyUrl: texteOuNull(json['spotify_url']),
      youtubeUrl: texteOuNull(json['youtube_url']),
      appleMusicUrl: texteOuNull(json['apple_music_url']),
      deezerUrl: texteOuNull(json['deezer_url']),
      audiomackUrl: texteOuNull(json['audiomack_url']),
      audioUrl: texteOuNull(json['audio_url']),
      audioHqUrl: texteOuNull(json['audio_hq_url']),
      posterUrl: texteOuNull(json['poster_url']),
      paroles: texteOuNull(json['paroles']),
      premium: booleen(json['premium']),
      artisteSlug: texte(json['artiste_slug']),
      artisteNom: texte(json['artiste_nom']),
    );
  }

  Map<String, dynamic> versJson() => {
        'id': id,
        'titre': titre,
        'duree_secondes': dureeSecondes,
        'annee': annee,
        'spotify_url': spotifyUrl,
        'youtube_url': youtubeUrl,
        'apple_music_url': appleMusicUrl,
        'deezer_url': deezerUrl,
        'audiomack_url': audiomackUrl,
        'audio_url': audioUrl,
        'audio_hq_url': audioHqUrl,
        'poster_url': posterUrl,
        'paroles': paroles,
        'premium': premium,
        'artiste_slug': artisteSlug,
        'artiste_nom': artisteNom,
      };

  @override
  List<Object?> get props =>
      [id, titre, dureeSecondes, annee, spotifyUrl, youtubeUrl, appleMusicUrl, deezerUrl, audiomackUrl, audioUrl, audioHqUrl, posterUrl, paroles, premium, artisteSlug, artisteNom];
}
