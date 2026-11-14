import 'models/artiste.dart';
import 'models/artiste_detail.dart';
import 'models/film.dart';
import 'models/morceau.dart';
import 'models/produit.dart';

/// Provenance des données affichées. L'interface s'en sert pour dire
/// honnêtement à la personne d'où vient ce qu'elle voit.
enum OrigineDonnees {
  /// Réponse fraîche de l'API.
  reseau,

  /// Dernière réponse connue de l'API, relue depuis le cache local.
  cache,

  /// Catalogue de secours embarqué dans l'application.
  local;

  bool get horsLigne => this != OrigineDonnees.reseau;

  String get libelle => switch (this) {
        OrigineDonnees.reseau => 'Catalogue à jour',
        OrigineDonnees.cache => 'Dernière version enregistrée',
        OrigineDonnees.local => 'Catalogue embarqué',
      };
}

/// Enveloppe un résultat avec sa provenance. Immuable.
class Resultat<T> {
  const Resultat(this.donnees, this.origine);

  final T donnees;
  final OrigineDonnees origine;

  bool get estVide {
    final valeur = donnees;
    if (valeur is Iterable) return valeur.isEmpty;
    if (valeur is String) return valeur.isEmpty;
    return valeur == null;
  }
}

/// Erreur métier du catalogue : message déjà rédigé pour l'utilisateur.
class ErreurCatalogue implements Exception {
  const ErreurCatalogue(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() => details == null ? message : '$message ($details)';
}

/// Contrat du catalogue, indépendant du transport.
///
/// L'interface ne connaît que cette abstraction : les tests injectent une
/// implémentation mémoire, l'application une implémentation HTTP.
abstract class DepotCatalogue {
  Future<Resultat<List<Film>>> films({String recherche = '', CategorieFilm? categorie});

  /// Films mis en avant par la rédaction (`vedette=true`).
  Future<Resultat<List<Film>>> filmsEnVedette({int limite = 6});

  Future<Resultat<Film>> film(String identifiant);

  Future<Resultat<List<Artiste>>> artistes({String recherche = ''});

  Future<Resultat<ArtisteDetail>> artiste(String identifiant);

  Future<Resultat<List<Produit>>> produits({String recherche = ''});

  Future<Resultat<Produit>> produit(String identifiant);

  /// Morceaux d'un artiste, pratique pour la fiche artiste côté écrans.
  Future<Resultat<List<Morceau>>> morceaux(String identifiantArtiste);
}
