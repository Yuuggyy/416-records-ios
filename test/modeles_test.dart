import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/models/film.dart';
import 'package:records416/domain/models/morceau.dart';
import 'package:records416/domain/models/produit.dart';

void main() {
  group('Film — lecture du contrat API', () {
    test('les champs null du backend ne cassent pas le modèle', () {
      final film = Film.depuisJson(const {
        'id': 42,
        'titre': 'Sans année',
        'categorie': 'clips',
        'annee': null,
        'duree_minutes': null,
        'affiche_url': '',
        'premium': false,
        'vedette': true,
        'artistes': <Object>[],
      });

      expect(film.id, 42);
      expect(film.titre, 'Sans année');
      expect(film.categorie, CategorieFilm.clips);
      expect(film.annee, isNull);
      expect(film.dureeMinutes, isNull);
      expect(film.aAffiche, isFalse);
      expect(film.dureeLisible, '—');
      expect(film.ficheTechnique, '');
      expect(film.artistes, isEmpty);
    });

    test('la catégorie retombe sur « films » si la valeur est inconnue', () {
      final film = Film.depuisJson(const {'id': 1, 'titre': 'X', 'categorie': 'inexistant'});
      expect(film.categorie, CategorieFilm.films);
      expect(film.libelleCategorie, 'Films');
    });

    test('libelleCategorie privilégie le libellé envoyé par l\'API', () {
      final film = Film.depuisJson(const {
        'id': 2,
        'titre': 'Battles',
        'categorie': 'competition',
        'categorie_libelle': 'Compétition',
      });
      expect(film.libelleCategorie, 'Compétition');
    });

    test('dureeLisible et ficheTechnique sont formatées proprement', () {
      const film = Film(id: 3, titre: 'Kinshasa Nights', annee: 2025, dureeMinutes: 92, genre: 'Thriller');
      expect(film.dureeLisible, '1 h 32');
      expect(film.ficheTechnique, '2025 · 1 h 32 · Thriller');

      const court = Film(id: 4, titre: 'Clip', dureeMinutes: 45);
      expect(court.dureeLisible, '45 min');

      const pile = Film(id: 5, titre: 'Pile', dureeMinutes: 120);
      expect(pile.dureeLisible, '2 h');
    });

    test('deux films identiques sont égaux (Equatable)', () {
      const a = Film(id: 7, titre: '416 Forever', annee: 2025);
      const b = Film(id: 7, titre: '416 Forever', annee: 2025);
      const c = Film(id: 8, titre: '416 Forever', annee: 2025);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('Produit — prix et devise', () {
    test('le prix texte de Django est converti en nombre', () {
      final produit = Produit.depuisJson(const {
        'id': 1,
        'nom': 'T-Shirt 416',
        'prix': '25.00',
        'devise': 'USD',
        'stock': 40,
        'tailles': ['S', 'M'],
      });
      expect(produit.prix, 25.0);
      expect(produit.enStock, isTrue);
      expect(produit.tailles, ['S', 'M']);
      expect(produit.aTailles, isTrue);
    });

    test('le stock nul marque le produit épuisé', () {
      final produit = Produit.depuisJson(const {
        'id': 4,
        'nom': 'Vinyle',
        'prix': '35.00',
        'stock': 0,
      });
      expect(produit.enStock, isFalse);
      expect(produit.quantiteDisponible(0), isFalse);
    });

    test('formaterPrix respecte la devise et les décimales', () {
      expect(formaterPrix(25, 'USD'), '25,00 \$US');
      expect(formaterPrix(45.5, 'USD'), '45,50 \$US');
      expect(formaterPrix(1250, 'CDF'), '1\u202F250,00 FC');
      expect(formaterPrix(0, 'USD'), '0,00 \$US');
      expect(formaterPrix(-3.256, 'EUR'), '-3,26 €');
    });
  });

  group('Morceau — durée', () {
    test('la durée est convertie en m:ss', () {
      const morceau = Morceau(id: 1, titre: 'Got It', dureeSecondes: 240);
      expect(morceau.dureeLisible, '4:00');
      const autre = Morceau(id: 2, titre: 'Rues de Kin', dureeSecondes: 210);
      expect(autre.dureeLisible, '3:30');
      const inconnu = Morceau(id: 3, titre: 'X');
      expect(inconnu.dureeLisible, '—');
    });
  });
}
