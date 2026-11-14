import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../domain/models/produit.dart';
import 'panier_screen.dart';

/// Fiche produit : visuel, description, choix de la taille, quantité, ajout au
/// panier. Une fois ajouté, un retour direct au panier est proposé.
class ProduitScreen extends StatefulWidget {
  const ProduitScreen({super.key, required this.produit});

  final Produit produit;

  @override
  State<ProduitScreen> createState() => _ProduitScreenState();
}

class _ProduitScreenState extends State<ProduitScreen> {
  late Produit _produit = widget.produit;
  late String _taille = widget.produit.tailles.isNotEmpty ? widget.produit.tailles.first : '';
  int _quantite = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rafraichir();
  }

  Future<void> _rafraichir() async {
    final depot = CatalogueScope.lire(context).depot;
    try {
      final resultat = await depot.produit(widget.produit.identifiant);
      if (!mounted) return;
      setState(() {
        _produit = resultat.donnees;
        if (_produit.tailles.isNotEmpty && !_produit.tailles.contains(_taille)) {
          _taille = _produit.tailles.first;
        }
      });
    } catch (_) {
      // On garde le produit fourni par la liste.
    }
  }

  void _ajouter() {
    final panier = CatalogueScope.lire(context).panier;
    panier.ajouter(_produit, taille: _taille, quantite: _quantite);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_produit.nom} ajouté au panier.'),
        action: SnackBarAction(
          label: 'Voir le panier',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PanierScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produit = _produit;
    final maximum = produit.stock > 0 ? produit.stock : 1;

    return Scaffold(
      appBar: AppBar(title: Text(produit.categorie.isEmpty ? 'Boutique' : produit.categorie)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.xl),
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ImageCatalogue(url: produit.imageUrl, icone: Icons.shopping_bag_outlined),
          ),
          const SizedBox(height: Espace.l),
          Text(
            produit.nom,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: Espace.s),
          Row(
            children: [
              Text(
                produit.prixLisible,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Pal.primaireClaire),
              ),
              const SizedBox(width: Espace.m),
              Etiquette(
                texte: produit.enStock ? 'EN STOCK' : 'ÉPUISÉ',
                couleur: produit.enStock ? Pal.succes : Pal.danger,
                icone: produit.enStock ? Icons.check_circle_outline : Icons.block,
              ),
            ],
          ),
          if (produit.description.isNotEmpty) ...[
            const SizedBox(height: Espace.m),
            Text(
              produit.description,
              style: const TextStyle(fontSize: 13, color: Pal.texte, height: 1.6),
            ),
          ],
          const SizedBox(height: Espace.l),
          if (produit.aTailles) ...[
            const Text(
              'TAILLE',
              style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: Pal.texteDoux, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Espace.s),
            Wrap(
              spacing: Espace.s,
              runSpacing: Espace.s,
              children: produit.tailles
                  .map(
                    (taille) => _PuceTaille(
                      libelle: taille,
                      actif: taille == _taille,
                      onTap: () => setState(() => _taille = taille),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: Espace.l),
          ],
          const Text(
            'QUANTITÉ',
            style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: Pal.texteDoux, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Espace.s),
          Row(
            children: [
              _BoutonPas(
                icone: Icons.remove,
                actif: _quantite > 1,
                onTap: () => setState(() => _quantite--),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_quantite',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              _BoutonPas(
                icone: Icons.add,
                actif: _quantite < maximum,
                onTap: () => setState(() => _quantite++),
              ),
              const Spacer(),
              Text(
                'Total ${formaterPrix(produit.prix * _quantite, produit.devise)}',
                style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
              ),
            ],
          ),
          if (produit.stock > 0 && produit.stock <= 5) ...[
            const SizedBox(height: Espace.s),
            Text(
              'Plus que ${produit.stock} en stock.',
              style: const TextStyle(fontSize: 11, color: Pal.alerte),
            ),
          ],
          const SizedBox(height: Espace.xl),
          FilledButton.icon(
            onPressed: produit.enStock ? _ajouter : null,
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: Text(produit.enStock ? 'Ajouter au panier' : 'Produit épuisé'),
          ),
          const SizedBox(height: Espace.m),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PanierScreen()),
            ),
            child: const Text('Voir le panier'),
          ),
        ],
      ),
    );
  }
}

class _PuceTaille extends StatelessWidget {
  const _PuceTaille({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rayons.champ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: Espace.s),
        decoration: BoxDecoration(
          color: actif ? Pal.primaire : Pal.surfaceHaute,
          borderRadius: BorderRadius.circular(Rayons.champ),
          border: Border.all(color: actif ? Pal.primaire : Pal.bordure),
        ),
        child: Text(
          libelle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : Pal.texteDoux,
          ),
        ),
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
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Pal.surfaceHaute,
          borderRadius: BorderRadius.circular(Rayons.champ),
          border: Border.all(color: Pal.bordure),
        ),
        child: Icon(icone, size: 16, color: actif ? Pal.texte : Pal.texteDoux.withAlpha(90)),
      ),
    );
  }
}
