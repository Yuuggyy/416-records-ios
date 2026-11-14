import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../data/depot_commandes.dart';
import '../../data/service_paiement_http.dart';
import '../paiement/paiement_en_ligne_screen.dart';
import '../../domain/models/panier.dart';
import '../../domain/models/produit.dart';

/// Tunnel de commande : coordonnées, taille et précisions, livraison, envoi.
///
/// La commande part réellement au serveur. Le paiement suit la règle du label :
/// règlement à la remise pour l'instant, le prestataire de paiement prenant le
/// relais dès qu'il est branché. Le serveur reste seul juge du total.
class CommandeScreen extends StatefulWidget {
  const CommandeScreen({super.key, required this.panier});

  final Panier panier;

  @override
  State<CommandeScreen> createState() => _CommandeScreenState();
}

class _CommandeScreenState extends State<CommandeScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _whatsapp = TextEditingController();
  final _adresse = TextEditingController();
  final _quartier = TextEditingController();
  final _notes = TextEditingController();
  final _depot = DepotCommandes();

  late final Map<String, TextEditingController> _precisions = {
    for (final ligne in widget.panier.lignes) ligne.cle: TextEditingController(),
  };

  String _mode = 'retrait';
  bool _payee = false;
  bool _envoi = false;
  String? _erreur;
  CommandeEnvoyee? _commande;

  @override
  void dispose() {
    _nom.dispose();
    _whatsapp.dispose();
    _adresse.dispose();
    _quartier.dispose();
    _notes.dispose();
    for (final c in _precisions.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_commande != null) return _confirmation(_commande!);

    return Scaffold(
      appBar: AppBar(title: const Text('Commander')),
      body: Form(
        key: _formulaire,
        child: ListView(
          padding: const EdgeInsets.all(Espace.m),
          children: [
            if (_erreur != null) ...[
              Container(
                padding: const EdgeInsets.all(Espace.s),
                decoration: BoxDecoration(
                  color: Pal.danger.withAlpha(30),
                  borderRadius: BorderRadius.circular(Rayons.champ),
                  border: Border.all(color: Pal.danger.withAlpha(90)),
                ),
                child: Text(
                  _erreur!,
                  style: const TextStyle(fontSize: 12, color: Pal.danger, height: 1.4),
                ),
              ),
              const SizedBox(height: Espace.m),
            ],
            _titre('Vos coordonnées'),
            _champ(
              controleur: _nom,
              etiquette: 'Nom',
              aide: 'Le nom que portera la commande',
              obligatoire: true,
            ),
            const SizedBox(height: Espace.s),
            _champ(
              controleur: _whatsapp,
              etiquette: 'Numéro WhatsApp',
              aide: 'Exemple : 0970000000',
              obligatoire: true,
              clavier: TextInputType.phone,
              validateur: (v) {
                final chiffres = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                if (chiffres.length < 9) return 'Indiquez un numéro valide';
                return null;
              },
            ),
            const SizedBox(height: Espace.l),
            _titre('Récupération'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'retrait', label: Text('Retrait'), icon: Icon(Icons.storefront_outlined, size: 16)),
                ButtonSegment(value: 'livraison', label: Text('Livraison'), icon: Icon(Icons.moped_outlined, size: 16)),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
            ),
            if (_mode == 'livraison') ...[
              const SizedBox(height: Espace.s),
              _champ(controleur: _adresse, etiquette: 'Adresse', aide: 'Rue, numéro, repère'),
              const SizedBox(height: Espace.s),
              _champ(controleur: _quartier, etiquette: 'Quartier / commune', aide: 'Facultatif mais utile au livreur'),
            ],
            const SizedBox(height: Espace.l),
            _titre('Vos articles'),
            ...widget.panier.lignes.map(_ligne),
            const SizedBox(height: Espace.l),
            _titre('Précisions'),
            _champ(
              controleur: _notes,
              etiquette: 'Message pour le label',
              aide: 'Couleur, délai, autre demande',
              lignes: 3,
            ),
            const SizedBox(height: Espace.l),
            _recapitulatif(),
            const SizedBox(height: Espace.m),
            FilledButton(
              onPressed: _envoi ? null : _envoyer,
              child: _envoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Envoyer la commande'),
            ),
            const SizedBox(height: Espace.s),
            const Text(
              'Le règlement se fait à la remise. Le label vous contacte sur WhatsApp pour confirmer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Pal.texteDoux, height: 1.4),
            ),
            const SizedBox(height: Espace.l),
          ],
        ),
      ),
    );
  }

  Widget _titre(String texte) => Padding(
        padding: const EdgeInsets.only(bottom: Espace.s),
        child: Text(
          texte.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Pal.texteDoux,
          ),
        ),
      );

  Widget _champ({
    required TextEditingController controleur,
    required String etiquette,
    String? aide,
    bool obligatoire = false,
    int lignes = 1,
    TextInputType? clavier,
    String? Function(String?)? validateur,
  }) {
    return TextFormField(
      controller: controleur,
      maxLines: lignes,
      keyboardType: clavier,
      decoration: InputDecoration(labelText: etiquette, helperText: aide),
      validator: validateur ??
          (obligatoire
              ? (v) => (v ?? '').trim().isEmpty ? 'Ce champ est nécessaire' : null
              : null),
    );
  }

  Widget _ligne(LignePanier ligne) {
    return Container(
      margin: const EdgeInsets.only(bottom: Espace.s),
      padding: const EdgeInsets.all(Espace.s),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ligne.nom,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '×${ligne.quantite}',
                style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${ligne.descriptionTaille} · ${formaterPrix(ligne.sousTotal, ligne.devise)}',
            style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
          ),
          const SizedBox(height: Espace.s),
          TextField(
            controller: _precisions[ligne.cle],
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Précision (facultatif)',
              hintText: 'Taille exacte, couleur…',
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _recapitulatif() {
    final panier = widget.panier;
    return Container(
      padding: const EdgeInsets.all(Espace.s),
      decoration: BoxDecoration(
        color: Pal.surfaceHaute,
        borderRadius: BorderRadius.circular(Rayons.carte),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${panier.nombreArticles} article${panier.nombreArticles > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: Pal.texteDoux),
          ),
          Text(
            panier.totalLisible,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(CommandeEnvoyee commande) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande envoyée')),
      body: ListView(
        padding: const EdgeInsets.all(Espace.m),
        children: [
          Container(
            padding: const EdgeInsets.all(Espace.m),
            decoration: BoxDecoration(
              color: Pal.surface,
              borderRadius: BorderRadius.circular(Rayons.carte),
              border: Border.all(color: Pal.primaire.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('C\'est enregistré.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: Espace.s),
                Text(
                  'Référence ${commande.reference}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pal.primaireClaire),
                ),
                const SizedBox(height: Espace.s),
                Text(
                  '${commande.statutLibelle} · ${commande.total} ${commande.devise}',
                  style: const TextStyle(fontSize: 13, color: Pal.texteDoux),
                ),
                const SizedBox(height: Espace.s),
                Text(
                  commande.modeLivraison == 'livraison'
                      ? 'Livraison : frais ${commande.fraisLivraison} ${commande.devise}, confirmés par WhatsApp.'
                      : 'Retrait au studio, frais de livraison nuls.',
                  style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.45),
                ),
                if (commande.instructionsPaiement.isNotEmpty) ...[
                  const SizedBox(height: Espace.s),
                  Text(
                    commande.instructionsPaiement,
                    style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Espace.m),
          if (_payee)
            const Padding(
              padding: EdgeInsets.only(bottom: Espace.m),
              child: Text('Paiement reçu. Merci !',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Pal.primaireClaire)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: Espace.m),
              child: FilledButton.icon(
                key: const ValueKey('payer-commande'),
                onPressed: () => _payerEnLigne(commande),
                icon: const Icon(Icons.phone_android, size: 18),
                label: Text('PAYER ${commande.total} ${commande.devise} PAR MOBILE MONEY'),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _depot.ecrireAuLabel(
              ApiConfig.whatsappBoutique,
              'Bonjour, je viens de commander sur l\'application 416 Records. '
                  'Ma référence est ${commande.reference} (${commande.total} ${commande.devise}).',
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Écrire au label sur WhatsApp'),
          ),
          const SizedBox(height: Espace.s),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Retour à la boutique'),
          ),
        ],
      ),
    );
  }

  Future<void> _payerEnLigne(CommandeEnvoyee commande) async {
    final service = ServicePaiementHttp();
    final dispo = await service.operateurs();
    if (!mounted) return;
    if (!dispo.disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le paiement en ligne n\'est pas disponible. Réglez via WhatsApp avec votre référence.'),
          backgroundColor: Pal.surfaceHaute,
        ),
      );
      return;
    }
    final paye = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PaiementEnLigneScreen(
          titre: 'Commande ${commande.reference}',
          resume: '${commande.total} ${commande.devise}',
          service: service,
          numeroInitial: _whatsapp.text,
          lancer: (c, numero, operateur) => c.payerCommande(
            reference: commande.reference,
            whatsapp: _whatsapp.text,
            numero: numero,
            operateur: operateur,
          ),
        ),
      ),
    );
    if (mounted && paye == true) setState(() => _payee = true);
  }

  Future<void> _envoyer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final commande = await _depot.envoyer(
        panier: widget.panier,
        nom: _nom.text,
        whatsapp: _whatsapp.text,
        modeLivraison: _mode,
        adresse: _adresse.text,
        quartier: _quartier.text,
        notes: _notes.text,
        precisions: {
          for (final e in _precisions.entries) e.key: e.value.text,
        },
      );
      if (!mounted) return;
      CatalogueScope.of(context).panier.vider();
      setState(() {
        _commande = commande;
        _envoi = false;
      });
    } on ErreurCommande catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.message;
        _envoi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = 'La commande n\'a pas abouti. Réessayez dans un instant.';
        _envoi = false;
      });
    }
  }
}
