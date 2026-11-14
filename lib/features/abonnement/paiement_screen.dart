import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../domain/models/abonnement.dart';
import '../../domain/models/offre.dart';

/// Formulaire de paiement Mobile Money.
///
/// Aucune passerelle n'est branchée à ce stade : la personne paie depuis son
/// téléphone puis déclare ici le numéro de transaction. L'abonnement s'active
/// quand l'équipe 416 a vérifié le paiement. Le jour où une passerelle est
/// branchée côté serveur, seul le backend change : cet écran reste valable
/// comme solution de secours.
class PaiementScreen extends StatefulWidget {
  const PaiementScreen({super.key, required this.offre});

  final Offre offre;

  @override
  State<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends State<PaiementScreen> {
  final _formulaire = GlobalKey<FormState>();
  final TextEditingController _transaction = TextEditingController();
  final TextEditingController _preuve = TextEditingController();
  OperateurMobileMoney _operateur = OperateurMobileMoney.mpesa;
  String? _erreur;

  @override
  void dispose() {
    _transaction.dispose();
    _preuve.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    final controleur = CatalogueScope.lire(context).abonnement;
    setState(() => _erreur = null);

    final abonnement = await controleur.souscrire(
      offre: widget.offre,
      operateur: _operateur,
      numeroTransaction: _transaction.text.trim(),
      preuve: _preuve.text.trim(),
    );

    if (!mounted) return;
    if (abonnement == null) {
      setState(() => _erreur = controleur.erreur ?? 'Envoi impossible pour le moment.');
      return;
    }
    Navigator.of(context).pop(abonnement);
  }

  @override
  Widget build(BuildContext context) {
    final controleur = CatalogueScope.of(context).abonnement;

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement Mobile Money')),
      body: Form(
        key: _formulaire,
        child: ListView(
          padding: const EdgeInsets.all(Espace.m),
          children: [
            Container(
              padding: const EdgeInsets.all(Espace.m),
              decoration: BoxDecoration(
                color: Pal.surface,
                borderRadius: BorderRadius.circular(Rayons.carte),
                border: Border.all(color: Pal.bordure),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.offre.nom, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.offre.dureeAffichee} · ${widget.offre.prixAffiche}',
                    style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Espace.m),
            const Text(
              '1. Payez depuis votre téléphone',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Espace.xs),
            Text(
              'Envoyez ${widget.offre.prixAffiche} au numéro 416 de votre opérateur, '
              'puis reportez ici le numéro de transaction reçu par SMS.',
              style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.5),
            ),
            const SizedBox(height: Espace.l),
            const Text('2. Opérateur utilisé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: Espace.s),
            Wrap(
              spacing: Espace.s,
              runSpacing: Espace.s,
              children: OperateurMobileMoney.values
                  .map(
                    (operateur) => ChoiceChip(
                      label: Text(operateur.libelle, style: const TextStyle(fontSize: 12)),
                      selected: _operateur == operateur,
                      onSelected: (_) => setState(() => _operateur = operateur),
                      selectedColor: Pal.primaire,
                      backgroundColor: Pal.surfaceHaute,
                      side: const BorderSide(color: Pal.bordure),
                      labelStyle: TextStyle(
                        color: _operateur == operateur ? Colors.white : Pal.texteDoux,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: Espace.l),
            const Text('3. Numéro de transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: Espace.s),
            TextFormField(
              controller: _transaction,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]'))],
              decoration: const InputDecoration(hintText: 'Ex. MP2605112345'),
              validator: (valeur) {
                final texte = (valeur ?? '').trim();
                if (texte.length < 6) return 'Saisissez le numéro reçu par SMS (au moins 6 caractères).';
                return null;
              },
            ),
            const SizedBox(height: Espace.m),
            TextFormField(
              controller: _preuve,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Facultatif : nom utilisé pour le paiement, heure, remarque',
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: Espace.m),
              Text(_erreur!, style: const TextStyle(fontSize: 12, color: Pal.danger)),
            ],
            const SizedBox(height: Espace.l),
            FilledButton(
              onPressed: controleur.souscriptionEnCours ? null : _envoyer,
              child: controleur.souscriptionEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Envoyer ma preuve de paiement'),
            ),
            const SizedBox(height: Espace.m),
            const Text(
              'Aucun prélèvement automatique. L\'accès s\'ouvre après vérification de la transaction '
              'par l\'équipe 416, généralement dans la journée.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
