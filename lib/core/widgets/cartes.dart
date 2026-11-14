import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../design/primitives.dart';
import '../../core/widgets/etats.dart';
import '../../domain/models/artiste.dart';
import '../../domain/models/film.dart';
import '../../domain/models/produit.dart';

/// Affiche une carte de film dans l'interface.
class CarteFilm extends StatelessWidget {
  const CarteFilm({
    super.key,
    required this.film,
    this.onTap,
    this.largeur = 132,
    this.afficherArtistes = false,
  });

  final Film film;
  final VoidCallback? onTap;
  final double largeur;
  final bool afficherArtistes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rayons.carte),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageCatalogue(url: film.afficheUrl, icone: Icons.movie_outlined),
                  if (film.premium)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Etiquette(texte: 'PREMIUM', couleur: Pal.primaire, icone: Icons.lock_outline),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Espace.s),
            Text(
              film.titre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
            ),
            const SizedBox(height: 2),
            Text(
              film.ficheTechnique.isEmpty ? film.libelleCategorie : film.ficheTechnique,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.meta.copyWith(fontSize: 10),
            ),
            if (afficherArtistes && film.artistes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                film.artistes.map((artiste) => artiste.nom).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.meta.copyWith(fontSize: 10, color: Pal.primaire),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne de film pleine largeur : plus de place pour le synopsis.
class LigneFilm extends StatelessWidget {
  const LigneFilm({super.key, required this.film, this.onTap});

  final Film film;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rayons.carte),
      child: Container(
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
              width: 74,
              height: 106,
              child: ImageCatalogue(url: film.afficheUrl, icone: Icons.movie_outlined, rayon: Rayons.champ),
            ),
            const SizedBox(width: Espace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    film.ficheTechnique,
                    style: Typo.meta.copyWith(fontSize: 10),
                  ),
                  if (film.synopsis.isNotEmpty) ...[
                    const SizedBox(height: Espace.s),
                    Text(
                      film.synopsis,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: Espace.s),
                  Wrap(
                    spacing: Espace.xs,
                    runSpacing: Espace.xs,
                    children: [
                      Etiquette(texte: film.libelleCategorie, couleur: Pal.primaireClaire),
                      if (film.premium)
                        const Etiquette(texte: 'PREMIUM', couleur: Pal.primaire, icone: Icons.lock_outline),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'artiste : une ligne d'index, plus de vignette ronde.
class CarteArtiste extends StatelessWidget {
  const CarteArtiste({super.key, required this.artiste, this.onTap});

  final Artiste artiste;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail = [artiste.genre, artiste.ville].where((v) => v.isNotEmpty).join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const Filet(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: ImageCatalogue(url: artiste.photoUrl, icone: Icons.person_outline, rayon: 0),
                  ),
                ),
                const SizedBox(width: Espace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artiste.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: Typo.texte,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Pal.texte,
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(detail.toUpperCase(), style: Typo.meta.copyWith(fontSize: 10)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_outward, size: 16, color: Pal.texteDoux),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte produit du merch.
class CarteProduit extends StatelessWidget {
  const CarteProduit({super.key, required this.produit, this.onTap, this.onAjouter});

  final Produit produit;
  final VoidCallback? onTap;
  final VoidCallback? onAjouter;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rayons.carte),
      child: Container(
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(Rayons.carte),
          border: Border.all(color: Pal.bordure),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ImageCatalogue(url: produit.imageUrl, icone: Icons.shopping_bag_outlined, rayon: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(Espace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    produit.prixLisible,
                    style: Typo.meta.copyWith(fontSize: 12, color: Pal.texte, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          produit.enStock
                              ? (produit.categorie.isEmpty ? 'DISPONIBLE' : produit.categorie.toUpperCase())
                              : 'ÉPUISÉ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.meta.copyWith(
                            fontSize: 9,
                            color: produit.enStock ? Pal.texteDoux : Pal.danger,
                          ),
                        ),
                      ),
                      if (onAjouter != null)
                        GestureDetector(
                          onTap: onAjouter,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            color: Pal.texte,
                            child: const Icon(Icons.add, size: 16, color: Pal.fond),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
