import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../domain/models/panier.dart';
import '../../domain/models/produit.dart';
import '../../state/controleur_panier.dart';
import 'commande_screen.dart';

/// Panier local : quantités, total, devise, vidage.
///
/// Aucune commande n'est envoyée : le backend n'expose pas encore de point de
/// commande. L'écran le dit clairement au lieu de laisser croire à un achat.
class PanierScreen extends StatelessWidget {
  const PanierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controleur = CatalogueScope.of(context).panier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier'),
        actions: [
          AnimatedBuilder(
            animation: controleur,
            builder: (context, _) {
              if (controleur.estVide) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: Espace.s),
                child: TextButton(
                  onPressed: () => _confirmerVidage(context, controleur),
                  child: const Text('Vider'),
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controleur,
        builder: (context, _) {
          if (!controleur.charge) {
            return const EtatChargement(message: 'Lecture du panier…');
          }
          if (controleur.estVide) {
            return EtatVide(
              message: 'Votre panier est vide.',
              details: 'Les pièces du 416 vous attendent dans la boutique.',
              icone: Icons.shopping_bag_outlined,
              action: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Retour à la boutique'),
              ),
            );
          }

          final panier = controleur.panier;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Espace.m, Espace.m, Espace.m, Espace.m),
                  itemCount: panier.lignes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Espace.s),
                  itemBuilder: (context, index) => _Ligne(
                    ligne: panier.lignes[index],
                    controleur: controleur,
                  ),
                ),
              ),
              _Recapitulatif(panier: panier),
            ],
          );
        },
      ),
    );
  }

  void _confirmerVidage(BuildContext context, ControleurPanier controleur) {
    showDialog<void>(
      context: context,
      builder: (dialogue) => AlertDialog(
        backgroundColor: Pal.surface,
        title: const Text('Vider le panier ?'),
        content: const Text('Toutes les lignes seront retirées.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogue).pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              controleur.vider();
              Navigator.of(dialogue).pop();
            },
            child: const Text('Vider', style: TextStyle(color: Pal.danger)),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne, required this.controleur});

  final LignePanier ligne;
  final ControleurPanier controleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.s),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.bordure),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: ImageCatalogue(url: ligne.imageUrl, icone: Icons.shopping_bag_outlined, rayon: Rayons.champ),
          ),
          const SizedBox(width: Espace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ligne.nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text(
                  ligne.descriptionTaille,
                  style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
                ),
                const SizedBox(height: Espace.s),
                Row(
                  children: [
                    _BoutonPas(
                      icone: Icons.remove,
                      actif: true,
                      onTap: () => controleur.decrementer(ligne),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${ligne.quantite}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _BoutonPas(
                      icone: Icons.add,
                      actif: ligne.peutAugmenter,
                      onTap: () => controleur.incrementer(ligne),
                    ),
                    const Spacer(),
                    Text(
                      formaterPrix(ligne.sousTotal, ligne.devise),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Pal.primaireClaire),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: () => controleur.retirer(ligne),
            icon: const Icon(Icons.close, size: 16, color: Pal.texteDoux),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _BoutonPas extends StatelessWidget {
  const _BoutonPas({required this.icone, required this.actif, required this.onTap});

  final IconData icone;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: actif ? onTap : null,
      borderRadius: BorderRadius.circular(Rayons.champ),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Pal.surfaceHaute,
          borderRadius: BorderRadius.circular(Rayons.champ),
          border: Border.all(color: Pal.bordure),
        ),
        child: Icon(icone, size: 14, color: actif ? Pal.texte : Pal.texteDoux.withAlpha(90)),
      ),
    );
  }
}

class _Recapitulatif extends StatelessWidget {
  const _Recapitulatif({required this.panier});

  final Panier panier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Espace.m, Espace.m, Espace.m, Espace.l),
      decoration: const BoxDecoration(
        color: Pal.surface,
        border: Border(top: BorderSide(color: Pal.bordure)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
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
            if (!panier.deviseHomogene) ...[
              const SizedBox(height: Espace.s),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Pal.alerte),
                  const SizedBox(width: Espace.s),
                  Expanded(
                    child: Text(
                      'Articles en plusieurs devises (${panier.devises.join(', ')}) : '
                      'le total est une somme indicative.',
                      style: const TextStyle(fontSize: 10, color: Pal.texteDoux, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Espace.m),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommandeScreen(panier: panier),
                ),
              ),
              child: const Text('Commander'),
            ),
            const SizedBox(height: Espace.s),
            const Text(
              'Vous réglez à la remise. Le label confirme la commande sur WhatsApp.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Pal.texteDoux, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

}
