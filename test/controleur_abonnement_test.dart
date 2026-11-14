import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/depot_abonnement.dart';
import 'package:records416/domain/models/abonnement.dart';
import 'package:records416/domain/models/offre.dart';
import 'package:records416/state/controleur_abonnement.dart';

/// Dépôt en mémoire : reproduit les états réels du backend.
class DepotAbonnementFaux implements DepotAbonnement {
  DepotAbonnementFaux({
    this.etatInitial = const EtatAbonnement(),
    this.refusLecture,
    this.echecSouscription,
  });

  EtatAbonnement etatInitial;
  String? refusLecture;
  String? echecSouscription;
  ErreurAbonnement? echecEtat;
  int souscriptions = 0;
  int lectures = 0;

  @override
  String? get cle => 'cle-test';

  @override
  Future<List<Offre>> offres() async => const [
        Offre(id: 1, nom: 'Mensuel', code: 'mensuel', prix: '4.00'),
        Offre(id: 2, nom: 'Annuel', code: 'annuel', prix: '40.00', dureeJours: 365, essaiJours: 7),
      ];

  @override
  Future<EtatAbonnement> monAbonnement() async {
    final e = echecEtat;
    if (e != null) throw e;
    return etatInitial;
  }

  @override
  Future<({Abonnement abonnement, Paiement paiement})> souscrire({
    required String codeOffre,
    required OperateurMobileMoney operateur,
    required String numeroTransaction,
    String preuve = '',
  }) async {
    souscriptions++;
    if (echecSouscription != null) throw ErreurAbonnement(echecSouscription!);
    const abonnement = Abonnement(
      id: 1,
      reference: 'AB-2026-000042',
      offre: Offre(id: 1, nom: 'Mensuel', code: 'mensuel', prix: '4.00'),
      statut: 'en_attente',
      paiements: [Paiement(id: 7, statut: 'en_attente')],
    );
    etatInitial = const EtatAbonnement(compte: 'demo', abonne: false, dernier: abonnement);
    return (abonnement: abonnement, paiement: const Paiement(id: 7, statut: 'en_attente'));
  }

  @override
  Future<LectureAutorisee> lectureFilm(String slug) async {
    lectures++;
    if (refusLecture != null) throw AccesRefuse(refusLecture!);
    return const LectureAutorisee(film: 'street-life', titre: 'Street Life', urlVideo: 'https://x/street.mp4');
  }
}

class StockageMemoire implements StockageCle {
  StockageMemoire([this.valeur]);

  String? valeur;

  @override
  Future<String?> lire() async => valeur;

  @override
  Future<void> ecrire(String? nouvelle) async => valeur = nouvelle;
}

void main() {
  test('sans clé, les offres restent consultables', () async {
    final stockage = StockageMemoire();
    final controleur = ControleurAbonnement(
      stockage: stockage,
      creerDepot: (_) => DepotAbonnementFaux(),
    );

    await controleur.initialiser();

    expect(controleur.aUneCle, isFalse);
    expect(controleur.offres.length, 2);
    expect(controleur.abonne, isFalse);
  });

  test('une clé enregistrée charge l\'état d\'abonnement', () async {
    final stockage = StockageMemoire('cle-abc');
    const abonnement = Abonnement(
      id: 3,
      reference: 'AB-2026-000010',
      offre: Offre(id: 2, nom: 'Annuel', code: 'annuel', prix: '40.00'),
      actif: true,
      joursRestants: 200,
    );
    final controleur = ControleurAbonnement(
      stockage: stockage,
      creerDepot: (_) => DepotAbonnementFaux(
        etatInitial: const EtatAbonnement(compte: 'demo', abonne: true, enCours: abonnement),
      ),
    );

    await controleur.initialiser();

    expect(controleur.aUneCle, isTrue);
    expect(controleur.abonne, isTrue);
    expect(controleur.abonnement?.reference, 'AB-2026-000010');
  });

  test('définir une clé la persiste pour les prochains lancements', () async {
    final stockage = StockageMemoire();
    final controleur = ControleurAbonnement(
      stockage: stockage,
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();

    await controleur.definirCle('  nouvelle-cle  ');

    expect(stockage.valeur, 'nouvelle-cle');
    expect(controleur.cle, 'nouvelle-cle');
  });

  test('une souscription en attente est signalée comme telle', () async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire('cle-abc'),
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();

    final abonnement = await controleur.souscrire(
      offre: const Offre(id: 1, nom: 'Mensuel', code: 'mensuel', prix: '4.00'),
      operateur: OperateurMobileMoney.orange,
      numeroTransaction: 'OM-2026-1',
    );

    expect(abonnement?.reference, 'AB-2026-000042');
    expect(controleur.enAttenteValidation, isTrue);
    expect(controleur.abonne, isFalse);
  });

  test('un échec de souscription laisse un message lisible', () async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire('cle-abc'),
      creerDepot: (_) => DepotAbonnementFaux(echecSouscription: 'numéro de transaction déjà utilisé'),
    );
    await controleur.initialiser();

    final abonnement = await controleur.souscrire(
      offre: const Offre(id: 1, nom: 'Mensuel', code: 'mensuel', prix: '4.00'),
      operateur: OperateurMobileMoney.mpesa,
      numeroTransaction: 'MP-1',
    );

    expect(abonnement, isNull);
    expect(controleur.erreur, contains('déjà utilisé'));
  });

  test('sans clé, la lecture d\'un film premium est refusée avant tout appel réseau', () async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire(),
      creerDepot: (_) => DepotAbonnementFaux(),
    );
    await controleur.initialiser();

    await expectLater(
      controleur.lectureFilm('street-life'),
      throwsA(isA<AccesRefuse>()),
    );
  });

  test('le refus du serveur remonte le message exact', () async {
    final controleur = ControleurAbonnement(
      stockage: StockageMemoire('cle-abc'),
      creerDepot: (_) => DepotAbonnementFaux(
        refusLecture: 'Cette vidéo est réservée aux abonnés 416.',
      ),
    );
    await controleur.initialiser();

    await expectLater(
      controleur.lectureFilm('street-life'),
      throwsA(isA<AccesRefuse>().having((e) => e.message, 'message', contains('réservée aux abonnés'))),
    );
  });

  group('session persistante', () {
    test('un 401 sans motif (serveur qui se réveille) conserve la clé', () async {
      final stockage = StockageMemoire('cle-abc');
      final depot = DepotAbonnementFaux()..echecEtat = const ErreurAbonnement('refusée', statut: 401);
      final controleur = ControleurAbonnement(stockage: stockage, creerDepot: (_) => depot);
      await controleur.initialiser();
      expect(controleur.aUneCle, isTrue);
      expect(stockage.valeur, 'cle-abc');
      expect(controleur.motifDeconnexion, isNull);
    });

    test('un 5xx ou une panne conserve la clé', () async {
      final stockage = StockageMemoire('cle-abc');
      final depot = DepotAbonnementFaux()..echecEtat = const ErreurAbonnement('en panne', statut: 503);
      final controleur = ControleurAbonnement(stockage: stockage, creerDepot: (_) => depot);
      await controleur.initialiser();
      expect(stockage.valeur, 'cle-abc');
    });

    for (final entree in {
      'remplacee': 'autre téléphone',
      'desactivee': 'désactivé',
      'expiree': 'expiré',
    }.entries) {
      test('motif ${entree.key} : clé effacée et explication affichée', () async {
        final stockage = StockageMemoire('cle-abc');
        final depot = DepotAbonnementFaux()
          ..echecEtat = ErreurAbonnement('refusée', statut: 401, code: entree.key);
        final controleur = ControleurAbonnement(stockage: stockage, creerDepot: (_) => depot);
        await controleur.initialiser();
        expect(controleur.aUneCle, isFalse);
        expect(stockage.valeur, isNull);
        expect(controleur.motifDeconnexion, contains(entree.value));
      });
    }

    test('un motif inconnu du serveur ne déconnecte pas', () async {
      final stockage = StockageMemoire('cle-abc');
      final depot = DepotAbonnementFaux()
        ..echecEtat = const ErreurAbonnement('refusée', statut: 401, code: 'truc-nouveau');
      final controleur = ControleurAbonnement(stockage: stockage, creerDepot: (_) => depot);
      await controleur.initialiser();
      expect(stockage.valeur, 'cle-abc');
    });
  });
}
