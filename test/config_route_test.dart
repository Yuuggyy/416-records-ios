import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/config.dart';

void main() {
  const fonction =
      'https://base44.app/api/apps/6a10802fc1e2a32a74055143/functions/catalogue416/';

  group('ApiConfig.uri', () {
    test('sur un serveur REST classique, la route reste dans le chemin', () {
      final uri = ApiConfig.uri('https://api.416.cd/api/', 'films/street-life/',
          {'q': 'kin'});
      expect(uri.path, '/api/films/street-life/');
      expect(uri.queryParameters['q'], 'kin');
    });

    test('sur une fonction Base44, la route passe en paramètre', () {
      final uri = ApiConfig.uri(fonction, 'films/street-life/', {'q': 'kin'});
      expect(uri.path, '/api/apps/6a10802fc1e2a32a74055143/functions/catalogue416');
      expect(uri.queryParameters['route'], 'films/street-life');
      expect(uri.queryParameters['q'], 'kin');
    });

    test('la barre oblique finale du chemin ne casse pas la route', () {
      final uri = ApiConfig.uri(fonction, '/merch/');
      expect(uri.queryParameters['route'], 'merch');
    });

    test('sans paramètre, la requête reste propre', () {
      final uri = ApiConfig.uri(fonction, 'sante');
      expect(uri.queryParameters, {'route': 'sante'});
    });
  });
}
