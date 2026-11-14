import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:records416/core/scope.dart';
import 'package:records416/domain/depot_catalogue.dart';
import 'package:records416/domain/models/abonnement.dart';
import 'package:records416/domain/models/artiste.dart';
import 'package:records416/domain/models/artiste_detail.dart';
import 'package:records416/domain/models/morceau.dart';
import 'package:records416/domain/models/produit.dart';
import 'package:records416/domain/models/film.dart';
import 'package:records416/domain/models/offre.dart';
import 'package:records416/features/abonnement/offres_screen.dart';
import 'package:records416/state/controleur_abonnement.dart';
import 'package:records416/state/controleur_compte.dart';
import 'package:records416/state/controleur_panier.dart';

import 'compte_test.dart' show DepotComptesFaux;
import 'controleur_abonnement_test.dart' show DepotAbonnementFaux, StockageMemoire;

Widget _enveloppe(Widget enfant, ControleurAbonnement abonnement) {
  return CatalogueScope(
    depot: DepotCatalogueVide(),
    panier: ControleurPanier(),
    abonnement: abonnement,
    compte: ControleurCompte(depot: DepotComptesFaux(), abonnement: abonnement),
    child: MaterialApp(home: enfant),
  );
}

void main() {
  testWidgets('le message de refus du serveur est affiché en haut des offres', (tester) async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire(),
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();

    await tester.pumpWidget(
      _enveloppe(
        const OffresScreen(messageBlocage: 'Cette vidéo est réservée aux abonnés 416.'),
        controleur,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('réservée aux abonnés 416'), findsOneWidget);
    expect(find.text('Choisir une offre'), findsOneWidget);
    expect(find.text('Abonnement annuel 416'), findsNothing); // nom réel du faux dépôt
    expect(find.text('Annuel'), findsOneWidget);
    expect(find.text('Mensuel'), findsOneWidget);
  });

  testWidgets('sans clé, le champ d\'accès est proposé et la souscription reste bloquée', (tester) async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire(),
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();

    await tester.pumpWidget(_enveloppe(const OffresScreen(), controleur));
    await tester.pumpAndSettle();

    expect(find.text('Mon accès 416'), findsOneWidget);
    expect(find.text('Collez votre clé d\'abonnement'), findsOneWidget);

    final boutons = tester.widgetList<FilledButton>(find.byType(FilledButton)).toList();
    // Le bouton « Enregistrer » de la carte clé reste actif, les offres non.
    expect(boutons.first.onPressed, isNotNull);
    expect(boutons.last.onPressed, isNull);
  });

  testWidgets('un abonnement actif affiche ses dates et sa référence', (tester) async {
    const abonnement = Abonnement(
      id: 3,
      reference: 'AB-2026-000010',
      offre: Offre(id: 2, nom: 'Annuel', code: 'annuel', prix: '40.00'),
      dateDebut: '2026-11-05T10:00:00+00:00',
      dateFin: '2027-11-05T10:00:00+00:00',
      actif: true,
      joursRestants: 365,
      paiements: [Paiement(id: 1, recu: 'REC-2026-00001', statut: 'valide')],
    );
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire('cle-abc'),
      creerDepot: (_) => DepotAbonnementFaux(
        etatInitial: const EtatAbonnement(compte: 'demo', abonne: true, enCours: abonnement),
      ),
    );
    await controleur.initialiser();

    await tester.pumpWidget(_enveloppe(const OffresScreen(), controleur));
    await tester.pumpAndSettle();

    expect(find.text('Abonnement actif'), findsOneWidget);
    expect(find.text('AB-2026-000010'), findsOneWidget);
    expect(find.text('REC-2026-00001'), findsOneWidget);
    expect(find.text('365 jours restants'), findsOneWidget);
  });
}

/// Dépôt catalogue inutilisé par ces écrans, mais requis par la portée.
class DepotCatalogueVide implements DepotCatalogue {
  @override
  Future<Resultat<List<Film>>> films({String recherche = '', CategorieFilm? categorie}) async =>
      const Resultat([], OrigineDonnees.local);

  @override
  Future<Resultat<List<Film>>> filmsEnVedette({int limite = 6}) async =>
      const Resultat([], OrigineDonnees.local);

  @override
  Future<Resultat<Film>> film(String identifiant) async =>
      throw const ErreurCatalogue('non utilisé dans ce test');

  @override
  Future<Resultat<List<Artiste>>> artistes({String recherche = ''}) async =>
      const Resultat([], OrigineDonnees.local);

  @override
  Future<Resultat<ArtisteDetail>> artiste(String identifiant) async =>
      throw const ErreurCatalogue('non utilisé dans ce test');

  @override
  Future<Resultat<List<Produit>>> produits({String recherche = ''}) async =>
      const Resultat([], OrigineDonnees.local);

  @override
  Future<Resultat<Produit>> produit(String identifiant) async =>
      throw const ErreurCatalogue('non utilisé dans ce test');

  @override
  Future<Resultat<List<Morceau>>> morceaux(String identifiantArtiste) async =>
      const Resultat([], OrigineDonnees.local);
}
