import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/cartes.dart';
import '../../core/widgets/etats.dart';
import '../../domain/depot_catalogue.dart';
import '../../domain/models/produit.dart';
import '../../state/controleur_panier.dart';
import 'panier_screen.dart';
import 'produit_screen.dart';

/// Boutique merch : grille de produits, recherche, accès au panier.
class MerchScreen extends StatefulWidget {
  const MerchScreen({super.key});

  @override
  State<MerchScreen> createState() => _MerchScreenState();
}

class _MerchScreenState extends State<MerchScreen> {
  final TextEditingController _champ = TextEditingController();
  Future<Resultat<List<Produit>>>? _avenir;
  Timer? _minuteur;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avenir ??= _charger();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _champ.dispose();
    super.dispose();
  }

  Future<Resultat<List<Produit>>> _charger() {
    final depot = CatalogueScope.lire(context).depot;
    return depot.produits(recherche: _champ.text.trim());
  }

  void _rechercherAvecDelai(String _) {
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _avenir = _charger());
    });
  }

  void _relancer() => setState(() => _avenir = _charger());

  void _ouvrirPanier() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PanierScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final panier = CatalogueScope.of(context).panier;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Manchette(panier: panier, onPanier: _ouvrirPanier),
            Padding(
              padding: const EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.s),
              child: TextField(
                controller: _champ,
                onChanged: _rechercherAvecDelai,
                onSubmitted: (_) => _relancer(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: Pal.texte),
                decoration: InputDecoration(
                  hintText: 'T-shirt, hoodie, vinyle…',
                  prefixIcon: const Icon(Icons.search, size: 18, color: Pal.texteDoux),
                  suffixIcon: _champ.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Effacer',
                          onPressed: () {
                            _champ.clear();
                            _relancer();
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Resultat<List<Produit>>>(
                future: _avenir,
                builder: (context, instantane) {
                  if (instantane.connectionState != ConnectionState.done) {
                    return const SingleChildScrollView(
                      child: EtatChargement(message: 'Chargement de la boutique…'),
                    );
                  }
                  if (instantane.hasError) {
                    return EtatErreur(
                      message: 'La boutique est injoignable.',
                      details: '${instantane.error}',
                      onReessayer: _relancer,
                    );
                  }
                  final resultat = instantane.data;
                  if (resultat == null) {
                    return EtatErreur(message: 'Réponse vide du catalogue.', onReessayer: _relancer);
                  }
                  final produits = resultat.donnees;
                  if (produits.isEmpty) {
                    return EtatVide(
                      message: 'Aucun produit disponible.',
                      details: _champ.text.trim().isEmpty
                          ? 'La boutique se remplit bientôt.'
                          : 'Aucun article ne correspond à « ${_champ.text.trim()} ».',
                      icone: Icons.shopping_bag_outlined,
                      action: OutlinedButton(
                        onPressed: () {
                          _champ.clear();
                          _relancer();
                        },
                        child: const Text('Tout afficher'),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => _relancer(),
                    color: Pal.primaire,
                    child: LayoutBuilder(builder: (context, dim) {
                      final largeur = dim.maxWidth;
                      final colonnes = largeur < 600 ? 2 : (largeur < 1000 ? 3 : 4);
                      // Contenu centre et borne : les cartes ne s'etirent pas sur grand ecran.
                      final utile = largeur > 1100 ? 1100.0 : largeur;
                      final marge = (largeur - utile) / 2 + Espace.m;
                      final cote = (utile - 2 * Espace.m - (colonnes - 1) * Espace.m) / colonnes;
                      // Image carree + zone texte de hauteur fixe : jamais de texte coupe.
                      final echelle = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 2.2).toDouble();
                      // Au-delà de x1.3 (accessibilité), les cartes étroites reçoivent un supplément.
                      final supplement = echelle > 1.3 ? 40.0 * (echelle - 1.3) : 0.0;
                      final hauteur = cote + 124 * echelle + supplement;
                      return GridView.builder(
                      padding: EdgeInsets.fromLTRB(marge, Espace.s, marge, Espace.xl),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: colonnes,
                        mainAxisSpacing: Espace.m,
                        crossAxisSpacing: Espace.m,
                        mainAxisExtent: hauteur,
                      ),
                      itemCount: produits.length,
                      itemBuilder: (context, index) {
                        final produit = produits[index];
                        return CarteProduit(
                          produit: produit,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => ProduitScreen(produit: produit)),
                          ),
                          onAjouter: produit.enStock
                              ? () {
                                  panier.ajouter(
                                    produit,
                                    taille: produit.tailles.isNotEmpty ? produit.tailles.first : '',
                                  );
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text('${produit.nom} ajouté au panier'),
                                        backgroundColor: Pal.surfaceHaute,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                }
                              : null,
                        );
                      },
                    );
                    }),
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: panier,
              builder: (context, _) {
                if (panier.nombreArticles == 0) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: _ouvrirPanier,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.m),
                    padding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: 14),
                    color: Pal.primaire,
                    child: Row(
                      children: [
                        Text(
                          '${panier.badge} article${panier.nombreArticles > 1 ? 's' : ''}',
                          style: Typo.etiquette.copyWith(color: Pal.texte),
                        ),
                        const Spacer(),
                        Text('Voir le panier · ${panier.totalLisible}', style: Typo.etiquette.copyWith(color: Pal.texte)),
                        const SizedBox(width: Espace.s),
                        const Icon(Icons.arrow_forward, size: 16, color: Pal.texte),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Manchette de la boutique : titre, filet, accès au panier.
class _Manchette extends StatelessWidget {
  const _Manchette({required this.panier, required this.onPanier});

  final ControleurPanier panier;
  final VoidCallback onPanier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espace.m, Espace.m, Espace.m, Espace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('03 / MERCH', style: Typo.etiquette.copyWith(color: Pal.primaire)),
                const SizedBox(height: 6),
                Text('Boutique', style: Typo.titre.copyWith(fontSize: 30)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPanier,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: panier,
              builder: (context, _) => Row(
                children: [
                  Text(
                    panier.nombreArticles == 0 ? 'PANIER' : 'PANIER ${panier.badge}',
                    style: Typo.etiquette.copyWith(color: Pal.texte),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.shopping_bag_outlined, size: 18, color: Pal.texte),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
