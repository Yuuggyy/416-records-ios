import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/liens_ecoute.dart';
import 'package:records416/core/widgets/panneau_plateformes.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/models/abonnement.dart';
import 'package:records416/domain/models/morceau.dart';
import 'package:records416/domain/models/offre.dart';
import 'package:records416/state/controleur_abonnement.dart';

class DepotPrixVariable implements DepotAbonnement {
  String prix = '4.00';
  int lectures = 0;
  bool panne = false;

  @override
  String? get cle => 'k';

  @override
  Future<List<Offre>> offres() async {
    lectures++;
    if (panne) throw const ErreurAbonnement('hors ligne');
    return [Offre(id: 1, nom: 'Mensuel', code: 'mensuel', prix: prix)];
  }

  @override
  Future<EtatAbonnement> monAbonnement() async => const EtatAbonnement();

  @override
  Future<({Abonnement abonnement, Paiement paiement})> souscrire({
    required String codeOffre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<LectureAutorisee> lectureFilm(String slug) => throw UnimplementedError();
}

void main() {
  group('prix des offres', () {
    test('un changement de prix côté admin apparaît à la relecture suivante', () async {
      final depot = DepotPrixVariable();
      final c = ControleurAbonnement(stockage: _Stockage('k'), creerDepot: (_) => depot, cleInitiale: 'k');
      await c.rafraichir();
      expect(c.offres.first.prix, '4.00');
      depot.prix = '7.50';
      await c.rafraichir();
      expect(c.offres.first.prix, '7.50');
      expect(depot.lectures, 2);
    });

    test('panne réseau à la relecture : l\'ancienne liste reste affichée', () async {
      final depot = DepotPrixVariable();
      final c = ControleurAbonnement(stockage: _Stockage('k'), creerDepot: (_) => depot, cleInitiale: 'k');
      await c.rafraichir();
      depot.panne = true;
      await c.rafraichir();
      expect(c.offres, isNotEmpty);
      expect(c.offres.first.prix, '4.00');
    });
  });

  group('plateformes par morceau', () {
    Morceau morceau({String? spotify, String? youtube, String? deezer}) => Morceau(
        id: 1, titre: 'Ndoki', spotifyUrl: spotify, youtubeUrl: youtube, deezerUrl: deezer);

    test('seuls les liens renseignés et valides sont proposés', () {
      final liens = liensDuMorceau(morceau(
          spotify: 'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
          youtube: 'pas un lien',
          deezer: 'https://deezer.com/track/1'));
      expect(liens.map((l) => l.plateforme), [Plateforme.spotify, Plateforme.deezer]);
    });

    testWidgets('le panneau liste une ligne par plateforme', (t) async {
      final liens = liensDuMorceau(morceau(
          spotify: 'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC', youtube: 'https://youtu.be/x'));
      await t.pumpWidget(MaterialApp(home: Scaffold(body: PanneauPlateformes(titre: 'Ndoki', liens: liens))));
      expect(find.text('Ndoki'), findsOneWidget);
      expect(find.byKey(const ValueKey('plateforme-spotify')), findsOneWidget);
      expect(find.byKey(const ValueKey('plateforme-youtube')), findsOneWidget);
      expect(find.byKey(const ValueKey('plateforme-deezer')), findsNothing);
    });

    testWidgets('sans lien : message au lieu d\'une liste vide', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: PanneauPlateformes(titre: 'X', liens: []))));
      expect(find.textContaining('Pas encore disponible'), findsOneWidget);
    });
  });
}

class _Stockage implements StockageCle {
  _Stockage(this.valeur);
  String? valeur;
  @override
  Future<String?> lire() async => valeur;
  @override
  Future<void> ecrire(String? v) async => valeur = v;
}
