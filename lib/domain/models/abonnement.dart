import 'package:equatable/equatable.dart';

import 'offre.dart';

/// Opérateurs Mobile Money acceptés par le backend (`Paiement.OPERATEURS`).
enum OperateurMobileMoney {
  mpesa('mpesa', 'M-Pesa'),
  orange('orange', 'Orange Money'),
  airtel('airtel', 'Airtel Money'),
  airtimoney('airtimoney', 'Airtel Money (Airtimoney)');

  const OperateurMobileMoney(this.cle, this.libelle);

  final String cle;
  final String libelle;

  static OperateurMobileMoney? depuisCle(String? cle) {
    if (cle == null) return null;
    for (final operateur in values) {
      if (operateur.cle == cle) return operateur;
    }
    return null;
  }
}

/// Paiement rattaché à un abonnement. Un paiement envoyé depuis l'application
/// naît toujours « en_attente » : c'est l'équipe 416 qui le valide.
class Paiement extends Equatable {
  const Paiement({
    required this.id,
    this.recu,
    this.montant = '',
    this.devise = 'USD',
    this.operateur = '',
    this.operateurLibelle = '',
    this.numeroTransaction = '',
    this.statut = 'en_attente',
    this.statutLibelle = 'En attente',
    this.motifRefus,
    this.dateValidation,
  });

  final int id;
  final String? recu;
  final String montant;
  final String devise;
  final String operateur;
  final String operateurLibelle;
  final String numeroTransaction;
  final String statut;
  final String statutLibelle;
  final String? motifRefus;
  final String? dateValidation;

  bool get valide => statut == 'valide';
  bool get refuse => statut == 'refuse';
  bool get enAttente => statut == 'en_attente';

  factory Paiement.depuisJson(Map<String, dynamic> json) {
    return Paiement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      recu: json['recu'] as String?,
      montant: '${json['montant'] ?? ''}',
      devise: (json['devise'] as String?) ?? 'USD',
      operateur: (json['operateur'] as String?) ?? '',
      operateurLibelle: (json['operateur_libelle'] as String?) ?? '',
      numeroTransaction: (json['numero_transaction'] as String?) ?? '',
      statut: (json['statut'] as String?) ?? 'en_attente',
      statutLibelle: (json['statut_libelle'] as String?) ?? 'En attente',
      motifRefus: json['motif_refus'] as String?,
      dateValidation: json['date_validation'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, recu, montant, devise, operateur, numeroTransaction, statut, motifRefus, dateValidation];
}

/// Abonnement d'un compte à une offre.
class Abonnement extends Equatable {
  const Abonnement({
    required this.id,
    required this.reference,
    required this.offre,
    this.dateDebut,
    this.dateFin,
    this.statut = 'en_attente',
    this.statutLibelle = 'En attente',
    this.actif = false,
    this.joursRestants,
    this.essai = false,
    this.paiements = const [],
  });

  final int id;
  final String reference;
  final Offre offre;
  final String? dateDebut;
  final String? dateFin;
  final String statut;
  final String statutLibelle;

  /// Vrai seulement si l'abonnement couvre l'instant présent (calcul backend).
  final bool actif;
  final int? joursRestants;
  final bool essai;
  final List<Paiement> paiements;

  /// « 05/12/2026 » à partir de l'ISO renvoyé par le backend.
  String get finAffichee => _date(dateFin);

  String get debutAffichee => _date(dateDebut);

  String get joursAffiches {
    final jours = joursRestants;
    if (jours == null) return '';
    if (jours <= 0) return 'Échu';
    return jours == 1 ? '1 jour restant' : '$jours jours restants';
  }

  static String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final analyse = DateTime.tryParse(iso);
    if (analyse == null) return '—';
    final locale = analyse.toLocal();
    String deux(int valeur) => valeur.toString().padLeft(2, '0');
    return '${deux(locale.day)}/${deux(locale.month)}/${locale.year}';
  }

  factory Abonnement.depuisJson(Map<String, dynamic> json) {
    final offreJson = json['offre'];
    final paiementsJson = json['paiements'];
    return Abonnement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reference: (json['reference'] as String?) ?? '',
      offre: Offre.depuisJson(offreJson is Map<String, dynamic> ? offreJson : const {}),
      dateDebut: json['date_debut'] as String?,
      dateFin: json['date_fin'] as String?,
      statut: (json['statut'] as String?) ?? 'en_attente',
      statutLibelle: (json['statut_libelle'] as String?) ?? 'En attente',
      actif: json['actif'] as bool? ?? false,
      joursRestants: (json['jours_restants'] as num?)?.toInt(),
      essai: json['essai'] as bool? ?? false,
      paiements: paiementsJson is List
          ? paiementsJson
              .whereType<Map<String, dynamic>>()
              .map(Paiement.depuisJson)
              .toList(growable: false)
          : const [],
    );
  }

  @override
  List<Object?> get props =>
      [id, reference, offre, dateDebut, dateFin, statut, actif, joursRestants, essai, paiements];
}

/// État complet renvoyé par `GET /api/abonnements/mon-abonnement/`.
class EtatAbonnement extends Equatable {
  const EtatAbonnement({
    this.compte = '',
    this.abonne = false,
    this.enCours,
    this.dernier,
  });

  final String compte;

  /// Vrai si un abonnement couvre l'instant présent.
  final bool abonne;
  final Abonnement? enCours;
  final Abonnement? dernier;

  /// L'abonnement à afficher : celui en cours, sinon le dernier connu.
  Abonnement? get pertinent => enCours ?? dernier;

  /// Vrai quand un paiement attend encore la validation de l'équipe 416.
  bool get enAttenteValidation {
    final abonnement = pertinent;
    if (abonnement == null || abonne) return false;
    return abonnement.paiements.any((p) => p.enAttente);
  }

  factory EtatAbonnement.depuisJson(Map<String, dynamic> json) {
    final enCours = json['abonnement_en_cours'];
    final dernier = json['dernier_abonnement'];
    return EtatAbonnement(
      compte: (json['compte'] as String?) ?? '',
      abonne: json['abonne'] as bool? ?? false,
      enCours: enCours is Map<String, dynamic> ? Abonnement.depuisJson(enCours) : null,
      dernier: dernier is Map<String, dynamic> ? Abonnement.depuisJson(dernier) : null,
    );
  }

  @override
  List<Object?> get props => [compte, abonne, enCours, dernier];
}

/// Résultat d'une demande de lecture d'un contenu premium.
class LectureAutorisee extends Equatable {
  const LectureAutorisee({
    required this.film,
    required this.titre,
    this.urlVideo,
    this.referenceAbonnement,
    this.expireLe,
  });

  final String film;
  final String titre;
  final String? urlVideo;
  final String? referenceAbonnement;
  final String? expireLe;

  factory LectureAutorisee.depuisJson(Map<String, dynamic> json) {
    return LectureAutorisee(
      film: (json['film'] as String?) ?? '',
      titre: (json['titre'] as String?) ?? '',
      urlVideo: json['video_url'] as String?,
      referenceAbonnement: json['abonnement_reference'] as String?,
      expireLe: json['expire_le'] as String?,
    );
  }

  @override
  List<Object?> get props => [film, titre, urlVideo, referenceAbonnement, expireLe];
}
