import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/lecture_json.dart';
import '../domain/depot_catalogue.dart';
import '../domain/models/artiste.dart';
import '../domain/models/artiste_detail.dart';
import '../domain/models/film.dart';
import '../domain/models/morceau.dart';
import '../domain/models/produit.dart';
import 'depot_local.dart';
import 'local/cache_catalogue.dart';

/// Dépôt branché sur l'API Django du catalogue, avec deux filets de sécurité :
///
///  1. **cache** : toute réponse valide est écrite dans [CacheCatalogue] ; si
///     l'API ne répond plus, on relit la dernière réponse connue ;
///  2. **repli local** : si le cache est vide (premier lancement hors ligne),
///     on sert le catalogue embarqué de [DepotLocal].
///
/// Conséquence pour l'interface : aucune méthode ne jette d'exception réseau.
/// Elle renvoie toujours un [Resultat] — au pire le repli local — et c'est
/// `origine` qui indique la fraîcheur. Seule une ressource réellement absente
/// (`404`) lève une [ErreurCatalogue].
class DepotHttp implements DepotCatalogue {
  DepotHttp({
    http.Client? client,
    String? baseUrl,
    CacheCatalogue? cache,
    DepotCatalogue? repli,
    Duration? delai,
  })  : _client = client ?? http.Client(),
        _baseUrl = ApiConfig.normaliser(baseUrl ?? ApiConfig.base),
        _cache = cache ?? CacheMemoire(),
        _repli = repli ?? DepotLocal(),
        _delai = delai ?? ApiConfig.delai;

  /// Limite imposée par le backend (`PER_PAGE_MAX = 60`).
  static const int taillePage = 60;

  /// Nombre maximal de pages parcourues par liste : garde-fou anti-boucle si
  /// le serveur renvoyait un `has_more` incohérent.
  static const int pagesMax = 10;

  final http.Client _client;
  final String _baseUrl;
  final CacheCatalogue _cache;
  final DepotCatalogue _repli;
  final Duration _delai;

  String get baseUrl => _baseUrl;

  /// Récupère une page et renvoie son `data` JSON décodé.
  ///
  /// Lève [ErreurCatalogue] sur 404 (ressource absente) et une
  /// [_EchecReseau] sur tout autre problème — l'appelant décide alors du repli.
  Future<Object?> _obtenir(String chemin, {Map<String, String>? parametres}) async {
    final uri = ApiConfig.uri(_baseUrl, chemin, parametres);

    late http.Response reponse;
    try {
      reponse = await _client.get(uri).timeout(_delai);
    } on TimeoutException {
      throw _EchecReseau('Délai dépassé', uri: uri);
    } catch (erreur) {
      throw _EchecReseau('Serveur injoignable', uri: uri, cause: '$erreur');
    }

    Object? charge;
    try {
      charge = jsonDecode(utf8.decode(reponse.bodyBytes));
    } catch (_) {
      throw _EchecReseau('Réponse illisible (HTTP ${reponse.statusCode})', uri: uri);
    }

    if (charge is! Map) {
      throw _EchecReseau('Format de réponse inattendu', uri: uri);
    }

    final carte = Map<String, dynamic>.from(charge);
    final erreur = texteOuNull(carte['error']);

    if (reponse.statusCode == 404) {
      throw ErreurCatalogue(erreur ?? 'Ressource introuvable', details: uri.path);
    }
    if (reponse.statusCode < 200 || reponse.statusCode >= 300) {
      throw _EchecReseau(
        erreur ?? 'HTTP ${reponse.statusCode}',
        uri: uri,
        statut: reponse.statusCode,
      );
    }
    if (erreur != null) {
      throw _EchecReseau(erreur, uri: uri, statut: reponse.statusCode);
    }
    return carte['data'];
  }

  /// Parcourt toutes les pages d'une liste (le backend pagine par 20).
  Future<List<Map<String, dynamic>>> _toutesLesPages(
    String chemin, {
    Map<String, String> parametres = const {},
  }) async {
    final cumul = <Map<String, dynamic>>[];
    var page = 1;
    var continuer = true;

    while (continuer && page <= pagesMax) {
      final data = await _obtenir(chemin, parametres: {
        ...parametres,
        'page': '$page',
        'per_page': '$taillePage',
      });
      final elements = listeObjets(data);
      cumul.addAll(elements);

      // Sans métadonnées de pagination, une page incomplète signifie la fin.
      continuer = elements.length >= taillePage;
      page++;
    }
    return cumul;
  }

  /// Exécute [appel] sur le réseau, puis bascule cache → repli local.
  Future<Resultat<T>> _avecRepli<T>({
    required String cleCache,
    required Future<T> Function() appel,
    required T Function(Object? json) depuisCache,
    required Future<Resultat<T>> Function() depuisRepli,
    bool ecrireCache = true,
  }) async {
    try {
      final valeur = await appel();
      if (ecrireCache) {
        unawaited(_cache.ecrire(cleCache, _versJson(valeur)));
      }
      return Resultat(valeur, OrigineDonnees.reseau);
    } on ErreurCatalogue {
      rethrow; // Ressource réellement absente : le repli ne la inventera pas.
    } on _EchecReseau {
      final memorise = await _cache.lire(cleCache);
      if (memorise != null) {
        try {
          return Resultat(depuisCache(memorise), OrigineDonnees.cache);
        } catch (_) {
          // Entrée de cache d'un ancien format : on l'ignore.
        }
      }
      return depuisRepli();
    }
  }

  /// Sérialise les modèles pour le cache (les modèles exposent `versJson`).
  static Object? _versJson(Object? valeur) {
    if (valeur is List) return valeur.map(_versJson).toList();
    if (valeur is Film) return valeur.versJson();
    if (valeur is Artiste) return valeur.versJson();
    if (valeur is ArtisteDetail) return valeur.versJson();
    if (valeur is Morceau) return valeur.versJson();
    if (valeur is Produit) return valeur.versJson();
    return valeur;
  }

  static const Map<CategorieFilm, String> _clesCategorie = {
    CategorieFilm.films: 'films',
    CategorieFilm.documentaires: 'documentaires',
    CategorieFilm.clips: 'clips',
    CategorieFilm.competition: 'competition',
  };

  String _cleFilms(String recherche, CategorieFilm? categorie) {
    final morceaux = <String>[
      'films',
      if (recherche.trim().isNotEmpty) 'q=${recherche.trim().toLowerCase()}',
      if (categorie != null) 'c=${_clesCategorie[categorie]}',
    ];
    return morceaux.join('_');
  }

  @override
  Future<Resultat<List<Film>>> films({String recherche = '', CategorieFilm? categorie}) {
    final requete = recherche.trim();
    final cle = _cleFilms(requete, categorie);

    return _avecRepli<List<Film>>(
      cleCache: cle,
      appel: () async {
        final brut = await _toutesLesPages('films/', parametres: {
          if (requete.isNotEmpty) 'q': requete,
          if (categorie != null) 'categorie': _clesCategorie[categorie]!,
        });
        return List<Film>.unmodifiable(brut.map(Film.depuisJson));
      },
      depuisCache: (json) => List<Film>.unmodifiable(
        listeObjets(json).map(Film.depuisJson),
      ),
      depuisRepli: () => _repli.films(recherche: requete, categorie: categorie),
    );
  }

  @override
  Future<Resultat<List<Film>>> filmsEnVedette({int limite = 6}) async {
    // On interroge l'API avec `vedette=1` : la sélection éditoriale vient du
    // backend, pas d'un filtre codé en dur dans l'application.
    final resultat = await _avecRepli<List<Film>>(
      cleCache: 'films_vedette',
      appel: () async {
        final brut = await _toutesLesPages('films/', parametres: {'vedette': '1'});
        return List<Film>.unmodifiable(brut.map(Film.depuisJson).take(limite));
      },
      depuisCache: (json) => List<Film>.unmodifiable(
        listeObjets(json).map(Film.depuisJson).take(limite),
      ),
      depuisRepli: () => _repli.filmsEnVedette(limite: limite),
    );
    return resultat;
  }

  @override
  Future<Resultat<Film>> film(String identifiant) {
    final slug = identifiant.trim();
    if (slug.isEmpty) {
      throw const ErreurCatalogue('Identifiant de film manquant.');
    }
    return _avecRepli<Film>(
      cleCache: 'film_$slug',
      appel: () async => Film.depuisJson(objet(await _obtenir('films/$slug/'))),
      depuisCache: (json) => Film.depuisJson(objet(json)),
      depuisRepli: () => _repli.film(slug),
    );
  }

  @override
  Future<Resultat<List<Artiste>>> artistes({String recherche = ''}) {
    final requete = recherche.trim();
    final cle = requete.isEmpty ? 'artistes' : 'artistes_q=${requete.toLowerCase()}';

    return _avecRepli<List<Artiste>>(
      cleCache: cle,
      appel: () async {
        final brut = await _toutesLesPages('artistes/', parametres: {
          if (requete.isNotEmpty) 'q': requete,
        });
        return List<Artiste>.unmodifiable(brut.map(Artiste.depuisJson));
      },
      depuisCache: (json) => List<Artiste>.unmodifiable(
        listeObjets(json).map(Artiste.depuisJson),
      ),
      depuisRepli: () => _repli.artistes(recherche: requete),
    );
  }

  @override
  Future<Resultat<ArtisteDetail>> artiste(String identifiant) {
    final slug = identifiant.trim();
    if (slug.isEmpty) {
      throw const ErreurCatalogue('Identifiant d\'artiste manquant.');
    }
    return _avecRepli<ArtisteDetail>(
      cleCache: 'artiste_$slug',
      appel: () async => ArtisteDetail.depuisJson(objet(await _obtenir('artistes/$slug/'))),
      depuisCache: (json) => ArtisteDetail.depuisJson(objet(json)),
      depuisRepli: () => _repli.artiste(slug),
    );
  }

  @override
  Future<Resultat<List<Produit>>> produits({String recherche = ''}) {
    final requete = recherche.trim();
    final cle = requete.isEmpty ? 'produits' : 'produits_q=${requete.toLowerCase()}';

    return _avecRepli<List<Produit>>(
      cleCache: cle,
      appel: () async {
        final brut = await _toutesLesPages('merch/', parametres: {
          if (requete.isNotEmpty) 'q': requete,
        });
        return List<Produit>.unmodifiable(brut.map(Produit.depuisJson));
      },
      depuisCache: (json) => List<Produit>.unmodifiable(
        listeObjets(json).map(Produit.depuisJson),
      ),
      depuisRepli: () => _repli.produits(recherche: requete),
    );
  }

  @override
  Future<Resultat<Produit>> produit(String identifiant) {
    final slug = identifiant.trim();
    if (slug.isEmpty) {
      throw const ErreurCatalogue('Identifiant de produit manquant.');
    }
    return _avecRepli<Produit>(
      cleCache: 'produit_$slug',
      appel: () async => Produit.depuisJson(objet(await _obtenir('merch/$slug/'))),
      depuisCache: (json) => Produit.depuisJson(objet(json)),
      depuisRepli: () => _repli.produit(slug),
    );
  }

  @override
  Future<Resultat<List<Morceau>>> morceaux(String identifiantArtiste) async {
    // L'API expose les morceaux dans la fiche artiste : une seule requête.
    final detail = await artiste(identifiantArtiste);
    return Resultat(detail.donnees.morceaux, detail.origine);
  }

  void fermer() => _client.close();
}

/// Panne réseau (ou réponse inexploitable) : déclenche le repli.
class _EchecReseau implements Exception {
  const _EchecReseau(this.message, {this.uri, this.statut, this.cause});

  final String message;
  final Uri? uri;
  final int? statut;
  final String? cause;

  @override
  String toString() {
    final parties = <String>[
      message,
      if (uri != null) uri.toString(),
      if (statut != null) 'HTTP $statut',
      if (cause != null) cause!,
    ];
    return 'EchecReseau: ${parties.join(' — ')}';
  }
}
