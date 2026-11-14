import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';
import 'artiste.dart';

/// Catégories éditoriales du catalogue, telles que définies par le backend
/// (`Film.CATEGORIES` dans `catalogue/models.py`).
enum CategorieFilm {
  films('films', 'Films'),
  documentaires('documentaires', 'Documentaires'),
  clips('clips', 'Clips'),
  competition('competition', 'Compétition');

  const CategorieFilm(this.cle, this.libelle);

  /// Valeur envoyée à l'API (`?categorie=…`).
  final String cle;

  /// Libellé affichable.
  final String libelle;

  static CategorieFilm? depuisCle(String? cle) {
    if (cle == null) return null;
    for (final categorie in values) {
      if (categorie.cle == cle) return categorie;
    }
    return null;
  }
}

/// Film, documentaire, clip ou épisode de compétition.
class Film extends Equatable {
  const Film({
    required this.id,
    required this.titre,
    this.slug = '',
    this.synopsis = '',
    this.categorie = CategorieFilm.films,
    this.categorieLibelle = '',
    this.genre = '',
    this.annee,
    this.dureeMinutes,
    this.afficheUrl,
    this.backdropUrl,
    this.videoUrl,
    this.premium = false,
    this.vedette = false,
    this.artistes = const [],
  });

  final int id;
  final String titre;
  final String slug;
  final String synopsis;
  final CategorieFilm categorie;

  /// Libellé renvoyé par le backend ; retombe sur [categorie] si absent.
  final String categorieLibelle;

  final String genre;
  final int? annee;
  final int? dureeMinutes;
  final String? afficheUrl;
  final String? backdropUrl;
  final String? videoUrl;
  final bool premium;
  final bool vedette;
  final List<Artiste> artistes;

  String get identifiant => slug.isNotEmpty ? slug : '$id';

  String get libelleCategorie =>
      categorieLibelle.isNotEmpty ? categorieLibelle : categorie.libelle;

  bool get aAffiche => afficheUrl != null && afficheUrl!.isNotEmpty;

  /// Durée lisible : « 1 h 32 » ou « 45 min ».
  String get dureeLisible {
    final minutes = dureeMinutes;
    if (minutes == null || minutes <= 0) return '—';
    if (minutes < 60) return '$minutes min';
    final heures = minutes ~/ 60;
    final reste = minutes % 60;
    return reste == 0 ? '$heures h' : '$heures h ${reste.toString().padLeft(2, '0')}';
  }

  /// « 2025 · 1 h 32 · Thriller », sans séparateur orphelin.
  String get ficheTechnique {
    final morceaux = <String>[
      if (annee != null) '$annee',
      if (dureeMinutes != null && dureeMinutes! > 0) dureeLisible,
      if (genre.isNotEmpty) genre,
    ];
    return morceaux.join(' · ');
  }

  factory Film.depuisJson(Map<String, dynamic> json) {
    return Film(
      id: entier(json['id']),
      titre: texte(json['titre']),
      slug: texte(json['slug']),
      synopsis: texte(json['synopsis']),
      categorie: CategorieFilm.depuisCle(texte(json['categorie'])) ?? CategorieFilm.films,
      categorieLibelle: texte(json['categorie_libelle']),
      genre: texte(json['genre']),
      annee: entierOuNull(json['annee']),
      dureeMinutes: entierOuNull(json['duree_minutes']),
      afficheUrl: texteOuNull(json['affiche_url']),
      backdropUrl: texteOuNull(json['backdrop_url']),
      videoUrl: texteOuNull(json['video_url']),
      premium: booleen(json['premium']),
      vedette: booleen(json['vedette']),
      artistes: List<Artiste>.unmodifiable(
        listeObjets(json['artistes']).map(Artiste.depuisJson),
      ),
    );
  }

  Map<String, dynamic> versJson() => {
        'id': id,
        'titre': titre,
        'slug': slug,
        'synopsis': synopsis,
        'categorie': categorie.cle,
        'categorie_libelle': categorieLibelle,
        'genre': genre,
        'annee': annee,
        'duree_minutes': dureeMinutes,
        'affiche_url': afficheUrl,
        'backdrop_url': backdropUrl,
        'video_url': videoUrl,
        'premium': premium,
        'vedette': vedette,
        'artistes': artistes.map((artiste) => artiste.versJson()).toList(),
      };

  @override
  List<Object?> get props => [
        id,
        titre,
        slug,
        synopsis,
        categorie,
        categorieLibelle,
        genre,
        annee,
        dureeMinutes,
        afficheUrl,
        backdropUrl,
        videoUrl,
        premium,
        vedette,
        artistes,
      ];
}
