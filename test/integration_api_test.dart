// Vérification de bout en bout contre le VRAI backend Django.
//
// Ce test n'utilise ni simulation ni données embarquées : il interroge l'API
// réelle (par défaut http://127.0.0.1:8416/api/) et contrôle que ce que
// l'application reçoit correspond au catalogue du label.
//
// Lancer d'abord le backend :
//   cd ../416_backend && python3 manage.py migrate && python3 manage.py seed_catalogue
//   python3 manage.py runserver 127.0.0.1:8416
// Puis :
//   flutter test test/integration_api_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:records416/data/depot_abonnement_http.dart';
import 'package:records416/data/depot_http.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/models/film.dart';

const _base = String.fromEnvironment('API_BASE', defaultValue: 'http://127.0.0.1:8416/api/');

/// Clé d'abonnement de test : fournie par `--dart-define=ABONNEMENT_KEY=…`.
const _cleTest = String.fromEnvironment('ABONNEMENT_KEY');

void main() {
  late bool serveurJoignable;

  setUpAll(() async {
    try {
      final r = await http.get(Uri.parse('${_base}sante/')).timeout(const Duration(seconds: 5));
      serveurJoignable = r.statusCode == 200;
    } catch (_) {
      serveurJoignable = false;
    }
  });

  test('le catalogue complet vient du backend Django', () async {
    if (!serveurJoignable) {
      markTestSkipped('Backend non lancé sur $_base — test d\'intégration ignoré.');
      return;
    }
    final depot = DepotHttp(baseUrl: _base);

    final sante = await http.get(Uri.parse('${_base}sante/'));
    expect(sante.statusCode, 200);
    expect(sante.body, contains('416-catalogue'));

    final films = await depot.films();
    expect(films.donnees, isNotEmpty);
    expect(films.origine.name, 'reseau', reason: 'les données doivent venir de l\'API, pas du repli local');
    expect(films.donnees.map((f) => f.titre), contains('Kinshasa Nights'));
    expect(films.donnees.any((f) => f.titre.startsWith('Battles 416')), isTrue);

    final competition = await depot.films(categorie: CategorieFilm.competition);
    expect(competition.donnees, isNotEmpty);
    expect(competition.donnees.every((f) => f.categorie == CategorieFilm.competition), isTrue);

    final recherche = await depot.films(recherche: 'thriller');
    expect(recherche.donnees.map((f) => f.titre), contains('Kinshasa Nights'));

    final fiche = await depot.film('kinshasa-nights');
    expect(fiche.donnees.dureeMinutes, 92);
    expect(fiche.donnees.synopsis, isNotEmpty);

    // Le documentaire « 416 Forever » est rattaché à Yuggy et Dreko côté API.
    final documentaire = await depot.film('416-forever');
    expect(documentaire.donnees.artistes.map((a) => a.nom), containsAll(['Yuggy', 'Dreko']));

    final artistes = await depot.artistes();
    expect(artistes.donnees.map((a) => a.nom), containsAll(['Yuggy', 'Dreko']));

    final ficheArtiste = await depot.artiste('yuggy');
    expect(ficheArtiste.donnees.morceaux.map((m) => m.titre), contains('Got It'));

    final produits = await depot.produits();
    expect(produits.donnees.map((p) => p.nom), contains('Hoodie 416 — Black'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('les abonnements répondent réellement (offres, état, refus premium)', () async {
    if (!serveurJoignable) {
      markTestSkipped('Backend non lancé sur $_base — test d\'intégration ignoré.');
      return;
    }

    // 1. Les offres sont publiques : consultables même sans compte.
    final sansCle = DepotAbonnementHttp(cle: null, baseUrl: _base);
    final offres = await sansCle.offres();
    expect(offres, isNotEmpty);
    expect(offres.map((o) => o.code), contains('mensuel'));
    expect(offres.map((o) => o.code), contains('annuel'));

    // 2. Sans clé, l'état est refusé proprement (401), pas par une erreur 500.
    await expectLater(
      sansCle.monAbonnement(),
      throwsA(isA<ErreurAbonnement>().having((e) => e.statut, 'statut', 401)),
    );

    // 3. Sans abonnement en cours, le film premium est refusé (402).
    await expectLater(
      sansCle.lectureFilm('street-life'),
      throwsA(isA<AccesRefuse>()),
    );

    if (_cleTest.isEmpty) return; // Le reste exige un compte réel.

    // 4. Avec une clé, le serveur renvoie un état cohérent.
    final avecCle = DepotAbonnementHttp(cle: _cleTest, baseUrl: _base);
    final etat = await avecCle.monAbonnement();
    expect(etat.compte, isNotEmpty);
    expect(etat.abonne, etat.enCours != null);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
