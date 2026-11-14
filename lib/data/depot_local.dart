import 'dart:convert';

import '../core/lecture_json.dart';
import '../domain/depot_catalogue.dart';
import '../domain/models/artiste.dart';
import '../domain/models/artiste_detail.dart';
import '../domain/models/film.dart';
import '../domain/models/morceau.dart';
import '../domain/models/produit.dart';
import 'local/catalogue_local.dart';

/// Dépôt hors ligne : lit le catalogue embarqué ([catalogueLocalJson]) et
/// applique localement la même recherche que l'API.
///
/// Il sert de repli quand l'API est injoignable et de base saine pour les
/// tests : aucun accès réseau, aucune horloge, résultats déterministes.
class DepotLocal implements DepotCatalogue {
  DepotLocal({String? json}) : _brut = _decoder(json ?? catalogueLocalJson);

  static Map<String, dynamic> _decoder(String json) {
    final charge = jsonDecode(json);
    if (charge is! Map) {
      throw const ErreurCatalogue('Catalogue embarqué illisible.');
    }
    return Map<String, dynamic>.from(charge);
  }

  final Map<String, dynamic> _brut;

  List<Film> get _films => listeObjets(_brut['films']).map(Film.depuisJson).toList();

  List<Artiste> get _artistes => listeObjets(_brut['artistes']).map(Artiste.depuisJson).toList();

  List<Produit> get _produits => listeObjets(_brut['produits']).map(Produit.depuisJson).toList();

  List<ArtisteDetail> get _details =>
      listeObjets(_brut['details']).map(ArtisteDetail.depuisJson).toList();

  /// Recherche insensible à la casse et aux accents — comme le `icontains`
  /// de Django, mais utilisable sans serveur.
  static bool _contient(String source, String recherche) {
    if (recherche.isEmpty) return true;
    return _sansAccent(source).contains(_sansAccent(recherche));
  }

  static String _sansAccent(String valeur) {
    const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const sans = 'aaaaaaceeeeiiiinooooouuuuyyoeae';
    final tampon = StringBuffer();
    for (final caractere in valeur.toLowerCase().split('')) {
      final index = avec.indexOf(caractere);
      tampon.write(index >= 0 ? sans[index] : caractere);
    }
    return tampon.toString();
  }

  @override
  Future<Resultat<List<Film>>> films({String recherche = '', CategorieFilm? categorie}) async {
    final resultat = _films.where((film) {
      if (categorie != null && film.categorie != categorie) return false;
      if (recherche.isEmpty) return true;
      return _contient(film.titre, recherche) ||
          _contient(film.synopsis, recherche) ||
          _contient(film.genre, recherche);
    }).toList();
    return Resultat(List<Film>.unmodifiable(resultat), OrigineDonnees.local);
  }

  @override
  Future<Resultat<List<Film>>> filmsEnVedette({int limite = 6}) async {
    final vedettes = _films.where((film) => film.vedette).toList();
    final selection = (vedettes.isEmpty ? _films : vedettes).take(limite).toList();
    return Resultat(List<Film>.unmodifiable(selection), OrigineDonnees.local);
  }

  @override
  Future<Resultat<Film>> film(String identifiant) async {
    for (final film in _films) {
      if (film.identifiant == identifiant) return Resultat(film, OrigineDonnees.local);
    }
    throw ErreurCatalogue('Film introuvable', details: identifiant);
  }

  @override
  Future<Resultat<List<Artiste>>> artistes({String recherche = ''}) async {
    final resultat = _artistes.where((artiste) {
      if (recherche.isEmpty) return true;
      return _contient(artiste.nom, recherche) ||
          _contient(artiste.genre, recherche) ||
          _contient(artiste.ville, recherche);
    }).toList();
    return Resultat(List<Artiste>.unmodifiable(resultat), OrigineDonnees.local);
  }

  @override
  Future<Resultat<ArtisteDetail>> artiste(String identifiant) async {
    for (final detail in _details) {
      if (detail.artiste.identifiant == identifiant) {
        return Resultat(detail, OrigineDonnees.local);
      }
    }
    throw ErreurCatalogue('Artiste introuvable', details: identifiant);
  }

  @override
  Future<Resultat<List<Produit>>> produits({String recherche = ''}) async {
    final resultat = _produits.where((produit) {
      if (recherche.isEmpty) return true;
      return _contient(produit.nom, recherche) ||
          _contient(produit.description, recherche) ||
          _contient(produit.categorie, recherche);
    }).toList();
    return Resultat(List<Produit>.unmodifiable(resultat), OrigineDonnees.local);
  }

  @override
  Future<Resultat<Produit>> produit(String identifiant) async {
    for (final produit in _produits) {
      if (produit.identifiant == identifiant) {
        return Resultat(produit, OrigineDonnees.local);
      }
    }
    throw ErreurCatalogue('Produit introuvable', details: identifiant);
  }

  @override
  Future<Resultat<List<Morceau>>> morceaux(String identifiantArtiste) async {
    for (final detail in _details) {
      if (detail.artiste.identifiant == identifiantArtiste) {
        return Resultat(detail.morceaux, OrigineDonnees.local);
      }
    }
    return const Resultat(<Morceau>[], OrigineDonnees.local);
  }
}
