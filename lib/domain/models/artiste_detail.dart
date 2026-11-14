import 'package:equatable/equatable.dart';

import '../../core/lecture_json.dart';
import 'artiste.dart';
import 'film.dart';
import 'morceau.dart';
import 'produit.dart';

/// Réponse de `GET /api/artistes/<slug>/` : la fiche complète d'un artiste,
/// avec ses morceaux et les films auxquels il participe.
class ArtisteDetail extends Equatable {
  const ArtisteDetail({
    required this.artiste,
    this.morceaux = const [],
    this.films = const [],
    this.produits = const [],
  });

  final Artiste artiste;
  final List<Morceau> morceaux;
  final List<Film> films;
  final List<Produit> produits;

  bool get vide => morceaux.isEmpty && films.isEmpty && produits.isEmpty;

  factory ArtisteDetail.depuisJson(Map<String, dynamic> json) {
    return ArtisteDetail(
      artiste: Artiste.depuisJson(json),
      morceaux: List<Morceau>.unmodifiable(
        listeObjets(json['morceaux']).map(Morceau.depuisJson),
      ),
      films: List<Film>.unmodifiable(
        listeObjets(json['films']).map(Film.depuisJson),
      ),
      produits: List<Produit>.unmodifiable(
        listeObjets(json['produits']).map(Produit.depuisJson),
      ),
    );
  }

  Map<String, dynamic> versJson() => {
        ...artiste.versJson(),
        'morceaux': morceaux.map((morceau) => morceau.versJson()).toList(),
        'films': films.map((film) => film.versJson()).toList(),
        'produits': produits.map((produit) => produit.versJson()).toList(),
      };

  @override
  List<Object?> get props => [artiste, morceaux, films, produits];
}
