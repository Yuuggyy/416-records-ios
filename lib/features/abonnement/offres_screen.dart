import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../domain/models/abonnement.dart';
import '../../domain/models/offre.dart';
import '../../data/service_paiement_http.dart';
import '../../domain/paiement_en_ligne.dart';
import '../paiement/paiement_en_ligne_screen.dart';
import 'paiement_screen.dart';

/// Écran des offres d'abonnement 416.
///
/// Trois situations, un seul écran :
///   * aucun compte configuré → on explique et on demande la clé 416 ;
///   * compte configuré sans abonnement → on propose les offres ;
///   * abonnement en cours → on montre l'état, les dates et le reçu.
///
/// Le blocage d'un contenu premium arrive ici avec le message du serveur
/// (`messageBlocage`) : l'application affiche la raison exacte du refus.
class OffresScreen extends StatefulWidget {
  const OffresScreen({super.key, this.messageBlocage, this.servicePaiement});

  /// Service de paiement en ligne imposé (tests). Par défaut : le serveur 416.
  final ServicePaiementEnLigne? servicePaiement;

  /// Message reçu du serveur quand un contenu premium a été refusé (HTTP 402).
  final String? messageBlocage;

  @override
  State<OffresScreen> createState() => _OffresScreenState();
}

class _OffresScreenState extends State<OffresScreen> {
  final TextEditingController _champCle = TextEditingController();
  bool _aCharge = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aCharge) return;
    _aCharge = true;
    final controleur = CatalogueScope.lire(context).abonnement;
    // A chaque ouverture : l'ancienne liste reste affichee pendant le
    // chargement, puis les prix du moment la remplacent.
    if (!controleur.chargement) {
      controleur.rafraichir();
    }
  }

  @override
  void dispose() {
    _champCle.dispose();
    super.dispose();
  }

  Future<void> _ouvrirPaiement(Offre offre) async {
    final controleur = CatalogueScope.lire(context).abonnement;
    // Paiement en ligne si le serveur l'offre ; sinon preuve Mobile Money manuelle.
    final service = widget.servicePaiement ?? ServicePaiementHttp(cle: controleur.cle);
    final enLigne = await service.operateurs();
    if (!mounted) return;
    if (enLigne.disponible) {
      final paye = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PaiementEnLigneScreen(
            titre: offre.nom,
            resume: '${offre.prixAffiche} · ${offre.dureeAffichee}',
            service: service,
            lancer: (c, numero, operateur) =>
                c.payerAbonnement(codeOffre: offre.code, numero: numero, operateur: operateur),
          ),
        ),
      );
      if (!mounted) return;
      await controleur.rafraichir();
      if (paye == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abonnement activé. Bonne écoute !'), backgroundColor: Pal.surfaceHaute),
        );
      }
      return;
    }
    final abonnement = await Navigator.of(context).push<Abonnement>(
      MaterialPageRoute<Abonnement>(builder: (_) => PaiementScreen(offre: offre)),
    );
    if (!mounted || abonnement == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demande enregistrée (${abonnement.reference}). L\'accès s\'ouvre après validation.'),
        backgroundColor: Pal.surfaceHaute,
      ),
    );
    await controleur.rafraichir();
  }

  Future<void> _enregistrerCle() async {
    final valeur = _champCle.text.trim();
    if (valeur.isEmpty) return;
    final controleur = CatalogueScope.lire(context).abonnement;
    await controleur.definirCle(valeur);
    if (!mounted) return;
    if (controleur.aUneCle) {
      _champCle.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controleur = CatalogueScope.of(context).abonnement;

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement 416')),
      body: AnimatedBuilder(
        animation: controleur,
        builder: (context, _) {
          final etat = controleur.etat;
          return RefreshIndicator(
            color: Pal.primaireClaire,
            backgroundColor: Pal.surface,
            onRefresh: controleur.rafraichir,
            child: ListView(
              padding: const EdgeInsets.all(Espace.m),
              children: [
                if (widget.messageBlocage != null) _BandeauBlocage(message: widget.messageBlocage!),
                if (controleur.abonne && etat?.enCours != null)
                  _CarteAbonnementEnCours(abonnement: etat!.enCours!)
                else ...[
                  const _Introduction(),
                  if (controleur.enAttenteValidation && etat?.pertinent != null)
                    _BandeauAttente(abonnement: etat!.pertinent!),
                ],
                const SizedBox(height: Espace.l),
                if (!controleur.aUneCle) ...[
                  _CarteCle(
                    controleur: _champCle,
                    onValider: _enregistrerCle,
                    erreur: controleur.erreur,
                  ),
                  const SizedBox(height: Espace.l),
                ],
                Text(
                  controleur.abonne ? 'Prolonger ou changer d\'offre' : 'Choisir une offre',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Espace.s),
                if (controleur.chargement && controleur.offres.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Espace.xl),
                    child: EtatChargement(message: 'Chargement des offres…'),
                  )
                else if (controleur.offres.isEmpty)
                  EtatErreur(
                    message: controleur.erreur ?? 'Aucune offre disponible pour le moment.',
                    onReessayer: controleur.rafraichir,
                  )
                else
                  ...controleur.offres.map(
                    (offre) => Padding(
                      padding: const EdgeInsets.only(bottom: Espace.s),
                      child: _CarteOffre(
                        offre: offre,
                        recommande: offre.code == 'annuel',
                        onChoisir: controleur.aUneCle ? () => _ouvrirPaiement(offre) : null,
                      ),
                    ),
                  ),
                if (!controleur.aUneCle) ...[
                  const SizedBox(height: Espace.s),
                  const Text(
                    'Renseignez la clé 416 pour souscrire : elle vous est remise par l\'équipe 416 '
                    'et rattache vos achats à votre compte.',
                    style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.45),
                  ),
                ],
                if (controleur.erreur != null && controleur.offres.isNotEmpty) ...[
                  const SizedBox(height: Espace.m),
                  Text(
                    controleur.erreur!,
                    style: const TextStyle(fontSize: 12, color: Pal.alerte),
                  ),
                ],
                const SizedBox(height: Espace.l),
                const _PiedDePage(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BandeauBlocage extends StatelessWidget {
  const _BandeauBlocage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Espace.m),
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.alerte.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Pal.alerte, size: 20),
          const SizedBox(width: Espace.s),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.45, color: Pal.texte),
            ),
          ),
        ],
      ),
    );
  }
}

class _Introduction extends StatelessWidget {
  const _Introduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rayons.carte),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1030), Color(0xFF0E0B14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Pal.bordure),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tout 416, sans limite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: Espace.s),
          Text(
            'Films, documentaires, clips et morceaux en écoute complète. '
            'Un abonnement couvre tous vos appareils.',
            style: TextStyle(fontSize: 13, color: Pal.texteDoux, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _CarteCle extends StatelessWidget {
  const _CarteCle({required this.controleur, required this.onValider, this.erreur});

  final TextEditingController controleur;
  final Future<void> Function() onValider;
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mon accès 416', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: Espace.s),
          TextField(
            controller: controleur,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Collez votre clé d\'abonnement',
              prefixIcon: Icon(Icons.key_outlined, size: 18),
            ),
            onSubmitted: (_) => onValider(),
          ),
          const SizedBox(height: Espace.s),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onValider,
              child: const Text('Enregistrer'),
            ),
          ),
          if (erreur != null) ...[
            const SizedBox(height: Espace.xs),
            Text(erreur!, style: const TextStyle(fontSize: 12, color: Pal.alerte)),
          ],
        ],
      ),
    );
  }
}

class _CarteOffre extends StatelessWidget {
  const _CarteOffre({required this.offre, required this.onChoisir, this.recommande = false});

  final Offre offre;
  final VoidCallback? onChoisir;
  final bool recommande;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: recommande ? Pal.primaire : Pal.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        offre.nom,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (recommande) ...[
                      const SizedBox(width: Espace.s),
                      Flexible(
                        flex: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: Espace.s, vertical: 2),
                          decoration: BoxDecoration(
                            color: Pal.primaire.withAlpha(60),
                            borderRadius: BorderRadius.circular(Rayons.pilule),
                          ),
                          child: const Text(
                            'Meilleur prix',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: Pal.primaireClaire),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${offre.dureeAffichee} · ${offre.prixParJour == null ? offre.prixAffiche : '${offre.prixAffiche} (${offre.prixParJour} \$/jour)'}',
                  style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
                ),
                if (offre.avecEssai) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Essai de ${offre.essaiJours} jours inclus',
                    style: const TextStyle(fontSize: 11, color: Pal.succes),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Espace.s),
          FilledButton(
            onPressed: onChoisir,
            style: FilledButton.styleFrom(
              backgroundColor: recommande ? Pal.primaire : Pal.surfaceHaute,
              foregroundColor: Pal.texte,
              padding: const EdgeInsets.symmetric(horizontal: Espace.s, vertical: Espace.s),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(offre.prixAffiche, maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }
}

class _CarteAbonnementEnCours extends StatelessWidget {
  const _CarteAbonnementEnCours({required this.abonnement});

  final Abonnement abonnement;

  @override
  Widget build(BuildContext context) {
    final paiement = abonnement.paiements.isEmpty ? null : abonnement.paiements.first;
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.succes.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: Pal.succes, size: 20),
              const SizedBox(width: Espace.s),
              const Text('Abonnement actif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(abonnement.joursAffiches, style: const TextStyle(fontSize: 11, color: Pal.succes)),
            ],
          ),
          const SizedBox(height: Espace.s),
          _Ligne(label: 'Offre', valeur: abonnement.offre.nom),
          _Ligne(label: 'Du', valeur: abonnement.debutAffichee),
          _Ligne(label: 'Au', valeur: abonnement.finAffichee),
          _Ligne(label: 'Référence', valeur: abonnement.reference),
          if (paiement?.recu != null) _Ligne(label: 'Reçu', valeur: paiement!.recu!),
        ],
      ),
    );
  }
}

class _BandeauAttente extends StatelessWidget {
  const _BandeauAttente({required this.abonnement});

  final Abonnement abonnement;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: Espace.m),
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.alerte.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_empty, color: Pal.alerte, size: 20),
          const SizedBox(width: Espace.s),
          Expanded(
            child: Text(
              'Paiement enregistré pour ${abonnement.reference}. '
              'L\'accès s\'ouvre dès que l\'équipe 416 a vérifié la transaction.',
              style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.label, required this.valeur});

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Espace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Pal.texteDoux)),
          ),
          Expanded(
            child: Text(valeur, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PiedDePage extends StatelessWidget {
  const _PiedDePage();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Paiement Mobile Money vérifié par l\'équipe 416. Aucun prélèvement automatique.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.45),
        ),
        SizedBox(height: Espace.m),
        Text('Inspire by YuuStore', style: TextStyle(fontSize: 11, color: Pal.texteDoux, letterSpacing: 0.5)),
        Text('+243 977 555 768', style: TextStyle(fontSize: 11, color: Pal.texteDoux)),
      ],
    );
  }
}
