import 'package:flutter_test/flutter_test.dart';
import 'package:records416/domain/models/abonnement.dart';
import 'package:records416/domain/models/offre.dart';

void main() {
  group('Offre', () {
    test('lit la réponse réelle du backend', () {
      final offre = Offre.depuisJson(const {
        'id': 4,
        'nom': 'Abonnement annuel 416',
        'code': 'annuel',
        'prix': '40.00',
        'devise': 'USD',
        'duree_jours': 365,
        'essai_jours': 7,
        'prix_par_jour': '0.1096',
        'actif': true,
      });

      expect(offre.code, 'annuel');
      expect(offre.dureeJours, 365);
      expect(offre.avecEssai, isTrue);
      expect(offre.prixAffiche, '40 USD');
      expect(offre.dureeAffichee, '365 jours');
    });

    test('garde les centimes quand le prix en a', () {
      final offre = Offre.depuisJson(const {'id': 1, 'nom': 'Mensuel', 'code': 'mensuel', 'prix': '4.50'});
      expect(offre.prixAffiche, '4.5 USD');
    });

    test('accepte une charge incomplète sans planter', () {
      final offre = Offre.depuisJson(const {});
      expect(offre.code, '');
      expect(offre.devise, 'USD');
      expect(offre.dureeJours, 30);
    });
  });

  group('Abonnement', () {
    Map<String, dynamic> charge({required bool actif, required int jours, String statut = 'actif'}) => {
          'id': 1,
          'reference': 'AB-2026-000001',
          'offre': {'id': 1, 'nom': 'Premium mensuel', 'code': 'mensuel', 'prix': '10.00'},
          'date_debut': '2026-11-05T15:00:00+00:00',
          'date_fin': '2026-12-05T15:00:00+00:00',
          'statut': statut,
          'statut_libelle': 'Actif',
          'actif': actif,
          'jours_restants': jours,
          'essai': false,
          'paiements': [
            {
              'id': 9,
              'recu': 'REC-2026-00009',
              'montant': '10.00',
              'devise': 'USD',
              'operateur': 'mpesa',
              'operateur_libelle': 'M-Pesa',
              'numero_transaction': 'MP2605112345',
              'statut': 'valide',
              'statut_libelle': 'Validé',
            }
          ],
        };

    test('abonnement en cours : dates et jours lisibles', () {
      final abonnement = Abonnement.depuisJson(charge(actif: true, jours: 12));
      expect(abonnement.reference, 'AB-2026-000001');
      expect(abonnement.actif, isTrue);
      expect(abonnement.joursAffiches, '12 jours restants');
      expect(abonnement.finAffichee, '05/12/2026');
      expect(abonnement.paiements.single.recu, 'REC-2026-00009');
      expect(abonnement.paiements.single.valide, isTrue);
    });

    test('abonnement échu : signalé comme tel', () {
      final abonnement = Abonnement.depuisJson(charge(actif: false, jours: 0, statut: 'expire'));
      expect(abonnement.actif, isFalse);
      expect(abonnement.joursAffiches, 'Échu');
    });
  });

  group('EtatAbonnement', () {
    test('abonne vrai seulement si un abonnement est en cours', () {
      final etat = EtatAbonnement.depuisJson(const {
        'compte': 'client-demo',
        'abonne': false,
        'abonnement_en_cours': null,
        'dernier_abonnement': {
          'id': 1,
          'reference': 'AB-2026-000002',
          'offre': {'id': 1, 'nom': 'Mensuel', 'code': 'mensuel', 'prix': '10.00'},
          'actif': false,
          'paiements': [
            {'id': 3, 'statut': 'en_attente', 'statut_libelle': 'En attente'}
          ],
        },
      });

      expect(etat.abonne, isFalse);
      expect(etat.enCours, isNull);
      expect(etat.pertinent?.reference, 'AB-2026-000002');
      expect(etat.enAttenteValidation, isTrue);
    });

    test('sans abonnement du tout, rien à afficher', () {
      final etat = EtatAbonnement.depuisJson(const {'compte': 'x', 'abonne': false});
      expect(etat.pertinent, isNull);
      expect(etat.enAttenteValidation, isFalse);
    });

    test('abonne vrai avec un abonnement en cours', () {
      final etat = EtatAbonnement.depuisJson(const {
        'compte': 'x',
        'abonne': true,
        'abonnement_en_cours': {
          'id': 2,
          'reference': 'AB-2026-000003',
          'offre': {'id': 1, 'nom': 'Annuel', 'code': 'annuel', 'prix': '40.00'},
          'actif': true,
          'jours_restants': 300,
        },
      });
      expect(etat.abonne, isTrue);
      expect(etat.enAttenteValidation, isFalse);
      expect(etat.enCours?.joursAffiches, '300 jours restants');
    });
  });

  test('LectureAutorisee reprend le flux autorisé', () {
    final lecture = LectureAutorisee.depuisJson(const {
      'film': 'street-life',
      'titre': 'Street Life',
      'video_url': 'https://exemple.416/street-life.mp4',
      'abonnement_reference': 'AB-2026-000001',
    });
    expect(lecture.urlVideo, 'https://exemple.416/street-life.mp4');
    expect(lecture.referenceAbonnement, 'AB-2026-000001');
  });
}
