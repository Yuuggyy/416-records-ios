import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/paiement_en_ligne.dart';
import '../../state/controleur_paiement.dart';

/// Écran de paiement Mobile Money en ligne, pour un abonnement ou une commande.
///
/// Le client choisit son opérateur et saisit son numéro ; il valide ensuite le
/// paiement sur son téléphone (code secret). L'écran suit l'état tout seul et
/// se ferme avec `true` quand le serveur confirme le paiement.
class PaiementEnLigneScreen extends StatefulWidget {
  const PaiementEnLigneScreen({
    super.key,
    required this.titre,
    required this.resume,
    required this.service,
    required this.lancer,
    this.numeroInitial = '',
    this.intervalle = const Duration(seconds: 3),
  });

  /// Ex. « Abonnement mensuel 416 ».
  final String titre;

  /// Ex. « 5.00 USD · 30 jours ».
  final String resume;

  final ServicePaiementEnLigne service;

  /// Lance le paiement avec le contrôleur ; appelle `payerAbonnement` ou
  /// `payerCommande` selon le contexte.
  final Future<void> Function(ControleurPaiement c, String numero, OperateurEnLigne? operateur) lancer;

  final String numeroInitial;
  final Duration intervalle;

  @override
  State<PaiementEnLigneScreen> createState() => _PaiementEnLigneScreenState();
}

class _PaiementEnLigneScreenState extends State<PaiementEnLigneScreen> {
  late final ControleurPaiement _c =
      ControleurPaiement(service: widget.service, intervalle: widget.intervalle);
  late final TextEditingController _numero = TextEditingController(text: widget.numeroInitial);
  OperateurEnLigne? _operateur;
  List<OperateurEnLigne> _operateurs = OperateurEnLigne.values;
  bool _sandbox = false;
  bool _charge = false;
  bool _disponible = true;

  @override
  void initState() {
    super.initState();
    _c.addListener(_surChangement);
    _chargerOperateurs();
  }

  Future<void> _chargerOperateurs() async {
    final r = await widget.service.operateurs();
    if (!mounted) return;
    setState(() {
      _charge = true;
      _disponible = r.disponible;
      _sandbox = r.sandbox;
      if (r.operateurs.isNotEmpty) _operateurs = r.operateurs;
    });
  }

  void _surChangement() {
    if (!mounted) return;
    setState(() {});
    if (_c.phase == PhasePaiement.reussi) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  @override
  void dispose() {
    _c.removeListener(_surChangement);
    _c.dispose();
    _numero.dispose();
    super.dispose();
  }

  Widget _carteOffre() => Container(
        padding: const EdgeInsets.all(Espace.m),
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(Rayons.carte),
          border: Border.all(color: Pal.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.resume, style: const TextStyle(fontSize: 12, color: Pal.texteDoux)),
          ],
        ),
      );

  Widget _bandeauTest() => Container(
        margin: const EdgeInsets.only(bottom: Espace.m),
        padding: const EdgeInsets.all(Espace.s),
        decoration: BoxDecoration(
          color: Pal.alerte.withAlpha(30),
          borderRadius: BorderRadius.circular(Rayons.champ),
          border: Border.all(color: Pal.alerte.withAlpha(120)),
        ),
        child: const Text(
          'MODE TEST : aucun argent réel n\'est prélevé. Pour réussir, utilisez 81 345 6789 '
          '(M-Pesa), 89 345 6789 (Orange) ou 97 345 6789 (Airtel).',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      );

  Widget _saisie() {
    final erreur = _c.erreur;
    return ListView(
      padding: const EdgeInsets.all(Espace.m),
      children: [
        _carteOffre(),
        const SizedBox(height: Espace.m),
        if (_sandbox) _bandeauTest(),
        if (_charge && !_disponible)
          const Padding(
            padding: EdgeInsets.only(bottom: Espace.m),
            child: Text('Le paiement en ligne est momentanément indisponible. Réessayez plus tard.',
                style: TextStyle(fontSize: 12, color: Pal.danger)),
          ),
        const Text('1. Votre opérateur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: Espace.s),
        Wrap(
          spacing: Espace.s,
          runSpacing: Espace.s,
          children: _operateurs
              .map((o) => ChoiceChip(
                    key: ValueKey('op-${o.code}'),
                    label: Text(o.libelle, style: const TextStyle(fontSize: 12)),
                    selected: _operateur == o,
                    onSelected: (_) => setState(() => _operateur = o),
                    selectedColor: Pal.primaire,
                    backgroundColor: Pal.surfaceHaute,
                    side: const BorderSide(color: Pal.bordure),
                    labelStyle: TextStyle(color: _operateur == o ? Colors.white : Pal.texteDoux, fontSize: 12),
                  ))
              .toList(),
        ),
        const SizedBox(height: Espace.l),
        const Text('2. Numéro à débiter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: Espace.s),
        TextField(
          key: const ValueKey('numero'),
          controller: _numero,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          decoration: const InputDecoration(prefixText: '+243  ', hintText: '81 234 5678'),
        ),
        if (erreur != null) ...[
          const SizedBox(height: Espace.s),
          Text(erreur, key: const ValueKey('erreur'), style: const TextStyle(fontSize: 12, color: Pal.danger)),
        ],
        const SizedBox(height: Espace.l),
        FilledButton(
          key: const ValueKey('payer'),
          onPressed: _c.occupe || (_charge && !_disponible)
              ? null
              : () => widget.lancer(_c, _numero.text, _operateur),
          child: _c.occupe
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('PAYER ${widget.resume.split(' · ').first}'),
        ),
        const SizedBox(height: Espace.s),
        const Text(
          'Vous recevrez une demande sur votre téléphone : saisissez votre code secret pour valider.',
          style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.5),
        ),
      ],
    );
  }

  Widget _attente() {
    final d = _c.depot;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_c.delaiDepasse) const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: Espace.l),
            Text(
              _c.delaiDepasse ? 'Toujours pas de confirmation' : 'Validez sur votre téléphone',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Espace.s),
            Text(
              _c.delaiDepasse
                  ? 'Si vous avez validé, le paiement peut encore arriver. Touchez « Vérifier » dans un instant. '
                      'Rien n\'est débité deux fois.'
                  : '${d?.operateur ?? ''} vous demande de confirmer ${d?.montantLisible ?? ''}. '
                      'Saisissez votre code secret.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Pal.texteDoux, height: 1.5),
            ),
            const SizedBox(height: Espace.l),
            OutlinedButton(
              key: const ValueKey('verifier'),
              onPressed: _c.verifier,
              child: const Text('VÉRIFIER'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultat({required bool ok}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Espace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ok ? Icons.check_circle : Icons.error_outline, size: 64, color: ok ? Pal.primaire : Pal.danger),
              const SizedBox(height: Espace.m),
              Text(ok ? 'Paiement reçu' : 'Paiement non abouti',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: Espace.s),
              Text(
                ok ? 'Merci. Votre accès est ouvert.' : (_c.erreur ?? 'Réessayez.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Pal.texteDoux, height: 1.5),
              ),
              if (!ok) ...[
                const SizedBox(height: Espace.l),
                FilledButton(
                  key: const ValueKey('reessayer'),
                  onPressed: _c.recommencer,
                  child: const Text('RÉESSAYER'),
                ),
              ],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final corps = switch (_c.phase) {
      PhasePaiement.saisie || PhasePaiement.envoi => _saisie(),
      PhasePaiement.attente => _attente(),
      PhasePaiement.reussi => _resultat(ok: true),
      PhasePaiement.echec => _resultat(ok: false),
    };
    return PopScope(
      canPop: _c.phase != PhasePaiement.envoi,
      child: Scaffold(
        appBar: AppBar(title: const Text('Paiement Mobile Money')),
        body: SafeArea(child: corps),
      ),
    );
  }
}
