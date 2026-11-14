import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:records416/data/depot_http.dart';
import 'package:records416/data/local/cache_catalogue.dart';
import 'package:records416/domain/depot_catalogue.dart';
import 'package:records416/domain/models/film.dart';

/// Construit une réponse API conforme au contrat du backend :
/// `{"data": ..., "error": null, "meta": {...}}`.
http.Response _reponse(Object? data, {Object? error, int statut = 200, Map<String, Object?>? meta}) {
  final charge = <String, Object?>{'data': data, 'error': error};
  if (meta != null) charge['meta'] = meta;
  return http.Response(
    jsonEncode(charge),
    statut,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _filmJson({
  int id = 1,
  String titre = 'Kinshasa Nights',
  String slug = 'kinshasa-nights',
  String categorie = 'films',
  bool vedette = true,
  bool premium = false,
  List<Map<String, Object?>> artistes = const [],
}) {
  return {
    'id': id,
    'titre': titre,
    'slug': slug,
    'synopsis': 'Un thriller urbain.',
    'categorie': categorie,
    'categorie_libelle': categorie == 'clips' ? 'Clips' : 'Films',
    'genre': 'Thriller',
    'annee': 2025,
    'duree_minutes': 92,
    'affiche_url': 'https://exemple.test/affiche.jpg',
    'backdrop_url': 'https://exemple.test/backdrop.jpg',
    'video_url': 'https://exemple.test/video.mp4',
    'premium': premium,
    'vedette': vedette,
    'artistes': artistes,
  };
}

void main() {
  group('DepotHttp — appels à l\'API', () {
    test('film() appelle le bon chemin et lit la réponse', () async {
      final uriVues = <Uri>[];
      final client = MockClient((requete) async {
        uriVues.add(requete.url);
        return _reponse(_filmJson());
      });

      final depot = DepotHttp(client: client, baseUrl: 'http://127.0.0.1:8416/api');
      final resultat = await depot.film('kinshasa-nights');

      expect(resultat.donnees.titre, 'Kinshasa Nights');
      expect(resultat.donnees.annee, 2025);
      expect(resultat.origine, OrigineDonnees.reseau);
      expect(uriVues.single.toString(), 'http://127.0.0.1:8416/api/films/kinshasa-nights/');
    });

    test('films() transmet la recherche et la catégorie', () async {
      final uriVues = <Uri>[];
      final client = MockClient((requete) async {
        uriVues.add(requete.url);
        return _reponse([_filmJson()], meta: {'count': 1, 'has_more': false});
      });

      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/');
      final resultat = await depot.films(recherche: 'Kin', categorie: CategorieFilm.clips);

      final uri = uriVues.single;
      expect(uri.path, '/api/films/');
      expect(uri.queryParameters['q'], 'Kin');
      expect(uri.queryParameters['categorie'], 'clips');
      expect(uri.queryParameters['per_page'], '60');
      expect(resultat.donnees.single.slug, 'kinshasa-nights');
    });

    test('films() parcourt les pages tant que la page est pleine', () async {
      var appels = 0;
      final client = MockClient((requete) async {
        appels++;
        final page = int.parse(requete.url.queryParameters['page'] ?? '1');
        // Page 1 pleine (60 éléments factices), page 2 avec 1 élément → fin.
        if (page == 1) {
          return _reponse(
            List.generate(60, (index) => _filmJson(id: index + 1, titre: 'F$index', slug: 'f-$index')),
            meta: {'page': 1, 'has_more': true},
          );
        }
        return _reponse([_filmJson(id: 99, titre: 'Dernier', slug: 'dernier')], meta: {'page': 2});
      });

      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/');
      final resultat = await depot.films();

      expect(appels, 2);
      expect(resultat.donnees.length, 61);
      expect(resultat.donnees.last.titre, 'Dernier');
    });

    test('film() lève une erreur claire sur 404', () async {
      final client = MockClient((_) async => _reponse(null, error: 'film introuvable', statut: 404));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/');

      expect(
        () => depot.film('inconnu'),
        throwsA(isA<ErreurCatalogue>().having((e) => e.message, 'message', 'film introuvable')),
      );
    });
  });

  group('DepotHttp — repli hors ligne', () {
    test('une panne réseau sert le catalogue embarqué', () async {
      final client = MockClient((_) async => throw Exception('connexion refusée'));
      final depot = DepotHttp(
        client: client,
        baseUrl: 'http://api.test/api/',
        cache: CacheMemoire(),
      );

      final resultat = await depot.films();

      expect(resultat.origine, OrigineDonnees.local);
      expect(resultat.donnees, isNotEmpty);
      expect(resultat.donnees.first.titre, isNotEmpty);
      expect(resultat.donnees.any((film) => film.premium), isTrue);
    });

    test('le cache sert la dernière réponse connue avant le repli local', () async {
      final cache = CacheMemoire();
      final depotEnLigne = DepotHttp(
        client: MockClient((_) async => _reponse([_filmJson(titre: 'Depuis le réseau')])),
        baseUrl: 'http://api.test/api/',
        cache: cache,
      );

      final enLigne = await depotEnLigne.films();
      expect(enLigne.origine, OrigineDonnees.reseau);
      // L'écriture du cache est asynchrone : on laisse une boucle se terminer.
      await Future<void>.delayed(Duration.zero);

      final depotHorsLigne = DepotHttp(
        client: MockClient((_) async => throw Exception('hors ligne')),
        baseUrl: 'http://api.test/api/',
        cache: cache,
      );
      final horsLigne = await depotHorsLigne.films();

      expect(horsLigne.origine, OrigineDonnees.cache);
      expect(horsLigne.donnees.single.titre, 'Depuis le réseau');
    });

    test('un 500 bascule aussi sur le repli', () async {
      final client = MockClient((_) async => _reponse(null, error: 'boom', statut: 500));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/', cache: CacheMemoire());

      final resultat = await depot.produits();

      expect(resultat.origine, OrigineDonnees.local);
      expect(resultat.donnees, isNotEmpty);
    });

    test('un JSON illisible bascule sur le repli au lieu de planter', () async {
      final client = MockClient((_) async => http.Response('<html>erreur</html>', 200));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/', cache: CacheMemoire());

      final resultat = await depot.artistes();

      expect(resultat.origine, OrigineDonnees.local);
      expect(resultat.donnees.length, greaterThanOrEqualTo(5));
    });

    test('un 404 n\'est pas masqué par le repli', () async {
      final client = MockClient((_) async => _reponse(null, error: 'produit introuvable', statut: 404));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/', cache: CacheMemoire());

      expect(() => depot.produit('fantome'), throwsA(isA<ErreurCatalogue>()));
    });

    test('la recherche est aussi filtrée dans le repli local', () async {
      final client = MockClient((_) async => throw Exception('hors ligne'));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/', cache: CacheMemoire());

      final resultat = await depot.films(recherche: 'cypher');
      expect(resultat.donnees, hasLength(1));
      expect(resultat.donnees.single.titre, 'The Cypher');

      final categories = await depot.films(categorie: CategorieFilm.documentaires);
      expect(categories.donnees, isNotEmpty);
      expect(categories.donnees.every((film) => film.categorie == CategorieFilm.documentaires), isTrue);
    });

    test('la fiche artiste du repli contient morceaux et films', () async {
      final client = MockClient((_) async => throw Exception('hors ligne'));
      final depot = DepotHttp(client: client, baseUrl: 'http://api.test/api/', cache: CacheMemoire());

      final resultat = await depot.artiste('yuggy');

      expect(resultat.origine, OrigineDonnees.local);
      expect(resultat.donnees.artiste.nom, 'Yuggy');
      expect(resultat.donnees.morceaux, isNotEmpty);
      expect(resultat.donnees.films, isNotEmpty);
    });
  });

  group('DepotHttp — configuration', () {
    test('l\'URL est normalisée avec un slash final', () {
      expect(DepotHttp(client: MockClient((_) async => _reponse([])), baseUrl: 'http://x.test/api')
          .baseUrl, 'http://x.test/api/');
      expect(DepotHttp(client: MockClient((_) async => _reponse([])), baseUrl: 'http://x.test/api/')
          .baseUrl, 'http://x.test/api/');
    });

    test('un délai dépassé déclenche le repli', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return _reponse([_filmJson()]);
      });
      final depot = DepotHttp(
        client: client,
        baseUrl: 'http://api.test/api/',
        cache: CacheMemoire(),
        delai: const Duration(milliseconds: 10),
      );

      final resultat = await depot.films();
      expect(resultat.origine, OrigineDonnees.local);
    });
  });
}
