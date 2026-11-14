import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';

/// Artiste du label 416, tel que renvoyé par `GET /api/artistes/`.
///
/// Objet de valeur immuable : deux artistes qui portent les mêmes données sont
/// égaux, ce qui permet de les comparer dans les tests et dans l'interface.
class Artiste extends Equatable {
  const Artiste({
    required this.id,
    required this.nom,
    this.slug = '',
    this.ville = '',
    this.bio = '',
    this.genre = '',
    this.photoUrl,
    this.coverUrl,
    this.spotifyUrl,
    this.youtubeUrl,
    this.appleMusicUrl,
    this.deezerUrl,
    this.audiomackUrl,
    this.vedette = false,
  });

  final int id;
  final String nom;
  final String slug;
  final String ville;
  final String bio;
  final String genre;
  final String? photoUrl;
  final String? coverUrl;
  final String? spotifyUrl;
  final String? youtubeUrl;
  final String? appleMusicUrl;
  final String? deezerUrl;
  final String? audiomackUrl;
  final bool vedette;

  /// Identifiant d'URL fiable même si le backend omet `slug`.
  String get identifiant => slug.isNotEmpty ? slug : '$id';

  bool get aPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  factory Artiste.depuisJson(Map<String, dynamic> json) {
    return Artiste(
      id: entier(json['id']),
      nom: texte(json['nom']),
      slug: texte(json['slug']),
      ville: texte(json['ville']),
      bio: texte(json['bio']),
      genre: texte(json['genre']),
      photoUrl: texteOuNull(json['photo_url']),
      coverUrl: texteOuNull(json['cover_url']),
      spotifyUrl: texteOuNull(json['spotify_url']),
      youtubeUrl: texteOuNull(json['youtube_url']),
      appleMusicUrl: texteOuNull(json['apple_music_url']),
      deezerUrl: texteOuNull(json['deezer_url']),
      audiomackUrl: texteOuNull(json['audiomack_url']),
      vedette: booleen(json['vedette']),
    );
  }

  Map<String, dynamic> versJson() => {
        'id': id,
        'nom': nom,
        'slug': slug,
        'ville': ville,
        'bio': bio,
        'genre': genre,
        'photo_url': photoUrl,
        'cover_url': coverUrl,
        'spotify_url': spotifyUrl,
        'youtube_url': youtubeUrl,
        'apple_music_url': appleMusicUrl,
        'deezer_url': deezerUrl,
        'audiomack_url': audiomackUrl,
        'vedette': vedette,
      };

  @override
  List<Object?> get props =>
      [id, nom, slug, ville, bio, genre, photoUrl, coverUrl, spotifyUrl, youtubeUrl, appleMusicUrl, deezerUrl, audiomackUrl, vedette];
}
