import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/models/film.dart';
import 'package:records416/state/ma_liste.dart';
import 'package:shared_preferences/shared_preferences.dart';

Film _film(String slug) => Film.depuisJson({'id': 1, 'slug': slug, 'titre': 'Street Life', 'affiche_url': 'https://x.cd/a.jpg'});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ajouter puis retirer un film', () async {
    final liste = MaListe.pourTest();
    expect(await liste.basculer(_film('street-life')), isTrue);
    expect(liste.contient('street-life'), isTrue);
    expect(await liste.basculer(_film('street-life')), isFalse);
    expect(liste.films, isEmpty);
  });

  test('la liste survit à un redémarrage', () async {
    await MaListe.pourTest().basculer(_film('street-life'));
    final relue = MaListe.pourTest();
    await relue.initialiser();
    expect(relue.films.single.titre, 'Street Life');
  });
}
