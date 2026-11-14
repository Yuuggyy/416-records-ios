import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/paiement_en_ligne.dart';

enum PhasePaiement { saisie, envoi, attente, reussi, echec }

/// Pilote un paiement en ligne : saisie, envoi, attente de validation sur le
/// téléphone, résultat. L'état est relu auprès du serveur toutes les
/// [intervalle] ; au bout de [delaiMax] on arrête sans conclure à un échec (le
/// paiement peut encore aboutir : on invite à vérifier plus tard).
class ControleurPaiement extends ChangeNotifier {
  ControleurPaiement({
    required this.service,
    this.intervalle = const Duration(seconds: 3),
    this.delaiMax = const Duration(minutes: 3),
  });

  final ServicePaiementEnLigne service;
  final Duration intervalle;
  final Duration delaiMax;

  PhasePaiement _phase = PhasePaiement.saisie;
  String? _erreur;
  DepotLance? _depot;
  bool _delaiDepasse = false;
  Timer? _minuteur;
  DateTime? _debutAttente;
  bool _libere = false;
  bool _interroge = false;

  PhasePaiement get phase => _phase;
  String? get erreur => _erreur;
  DepotLance? get depot => _depot;
  bool get delaiDepasse => _delaiDepasse;
  bool get occupe => _phase == PhasePaiement.envoi;

  void _changer(PhasePaiement p, {String? erreur}) {
    _phase = p;
    _erreur = erreur;
    if (!_libere) notifyListeners();
  }

  /// Validation locale du numéro : 9 chiffres après l'indicatif, avec ou sans 0.
  static String? verifierNumero(String brut) {
    var c = brut.replaceAll(RegExp(r'\D'), '');
    if (c.startsWith('00')) c = c.substring(2);
    if (c.startsWith('243')) c = c.substring(3);
    c = c.replaceFirst(RegExp(r'^0+'), '');
    if (!RegExp(r'^\d{9}$').hasMatch(c)) {
      return 'Numéro invalide : saisissez 9 chiffres (ex. 81 234 5678).';
    }
    return null;
  }

  Future<void> payerAbonnement({
    required String codeOffre,
    required String numero,
    required OperateurEnLigne? operateur,
  }) =>
      _lancer(numero, operateur, (op) => service.payerAbonnement(codeOffre: codeOffre, numero: numero, operateur: op));

  Future<void> payerCommande({
    required String reference,
    required String whatsapp,
    required String numero,
    required OperateurEnLigne? operateur,
  }) =>
      _lancer(
        numero,
        operateur,
        (op) => service.payerCommande(reference: reference, whatsapp: whatsapp, numero: numero, operateur: op),
      );

  Future<void> _lancer(
    String numero,
    OperateurEnLigne? operateur,
    Future<DepotLance> Function(OperateurEnLigne) action,
  ) async {
    if (occupe || _phase == PhasePaiement.attente) return;
    final probleme = verifierNumero(numero);
    if (probleme != null) {
      _changer(PhasePaiement.saisie, erreur: probleme);
      return;
    }
    if (operateur == null) {
      _changer(PhasePaiement.saisie, erreur: 'Choisissez votre opérateur.');
      return;
    }
    _changer(PhasePaiement.envoi);
    try {
      _depot = await action(operateur);
    } on ErreurPaiement catch (e) {
      _changer(PhasePaiement.echec, erreur: e.message);
      return;
    } catch (_) {
      _changer(PhasePaiement.echec, erreur: 'Paiement impossible pour le moment.');
      return;
    }
    _delaiDepasse = false;
    _debutAttente = DateTime.now();
    _changer(PhasePaiement.attente);
    _minuteur?.cancel();
    _minuteur = Timer.periodic(intervalle, (_) => verifier());
  }

  /// Relit l'état auprès du serveur. Appelable à la main (« J'ai validé »).
  Future<void> verifier() async {
    final d = _depot;
    if (d == null || _phase != PhasePaiement.attente || _interroge || _libere) return;
    _interroge = true;
    try {
      final s = await service.etat(d.identifiant);
      if (_libere) return;
      switch (s.etat) {
        case EtatDepot.paye:
          _minuteur?.cancel();
          _changer(PhasePaiement.reussi);
        case EtatDepot.echoue:
          _minuteur?.cancel();
          _changer(PhasePaiement.echec,
              erreur: s.motif.isEmpty ? 'Le paiement n\'a pas abouti.' : _traduire(s.motif));
        case EtatDepot.enAttente || EtatDepot.inconnu:
          final debut = _debutAttente;
          if (debut != null && DateTime.now().difference(debut) >= delaiMax) {
            _minuteur?.cancel();
            _delaiDepasse = true;
            if (!_libere) notifyListeners();
          }
      }
    } on ErreurPaiement {
      // Panne réseau passagère : on continue d'interroger.
    } finally {
      _interroge = false;
    }
  }

  static String _traduire(String motif) {
    final m = motif.toLowerCase();
    if (m.contains('did not approve') || m.contains('not_approved')) {
      return 'Vous n\'avez pas validé le paiement sur votre téléphone.';
    }
    if (m.contains('insufficient')) return 'Solde insuffisant sur votre compte Mobile Money.';
    if (m.contains('not found')) return 'Ce numéro n\'a pas de compte Mobile Money chez cet opérateur.';
    if (m.contains('limit')) return 'Plafond de votre compte atteint.';
    return 'Le paiement n\'a pas abouti. Réessayez.';
  }

  void recommencer() {
    _minuteur?.cancel();
    _depot = null;
    _delaiDepasse = false;
    _changer(PhasePaiement.saisie);
  }

  @override
  void dispose() {
    _libere = true;
    _minuteur?.cancel();
    super.dispose();
  }
}
