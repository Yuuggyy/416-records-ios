import 'package:flutter/material.dart';

import '../../domain/depot_catalogue.dart';
import '../theme.dart';

/// État de chargement : un squelette sobre, jamais un écran blanc.
class EtatChargement extends StatelessWidget {
  const EtatChargement({super.key, this.message = 'Chargement du catalogue…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Pal.primaireClaire),
            ),
            const SizedBox(height: Espace.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.texteDoux, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// État d'erreur : message clair, cause technique discrète, action de reprise.
class EtatErreur extends StatelessWidget {
  const EtatErreur({
    super.key,
    required this.message,
    this.details,
    this.onReessayer,
    this.libelleAction = 'Réessayer',
  });

  final String message;
  final String? details;
  final VoidCallback? onReessayer;
  final String libelleAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Espace.m),
              decoration: BoxDecoration(
                color: Pal.surface,
                borderRadius: BorderRadius.circular(Rayons.carte),
                border: Border.all(color: Pal.bordure),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, color: Pal.alerte, size: 26),
                  const SizedBox(height: Espace.m),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (details != null) ...[
                    const SizedBox(height: Espace.s),
                    Text(
                      details!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
                    ),
                  ],
                  if (onReessayer != null) ...[
                    const SizedBox(height: Espace.l),
                    OutlinedButton.icon(
                      onPressed: onReessayer,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(libelleAction),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État vide : dit ce qui manque et, si possible, comment en sortir.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.message,
    this.details,
    this.icone = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String? details;
  final IconData icone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: Pal.texteDoux, size: 30),
            const SizedBox(height: Espace.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (details != null) ...[
              const SizedBox(height: Espace.s),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Pal.texteDoux, height: 1.45),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Espace.l),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bandeau discret indiquant que l'affichage ne vient pas du réseau.
class BandeauOrigine extends StatelessWidget {
  const BandeauOrigine({super.key, required this.origine});

  final OrigineDonnees origine;

  @override
  Widget build(BuildContext context) {
    if (!origine.horsLigne) return const SizedBox.shrink();
    final local = origine == OrigineDonnees.local;
    return Container(
      margin: const EdgeInsets.only(bottom: Espace.m),
      padding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: Espace.s),
      decoration: BoxDecoration(
        color: Pal.surfaceHaute,
        borderRadius: BorderRadius.circular(Rayons.champ),
        border: Border.all(color: Pal.bordure),
      ),
      child: Row(
        children: [
          Icon(local ? Icons.inventory_2_outlined : Icons.history, size: 14, color: Pal.alerte),
          const SizedBox(width: Espace.s),
          Expanded(
            child: Text(
              local
                  ? 'API injoignable — catalogue embarqué affiché.'
                  : 'API injoignable — dernière version enregistrée affichée.',
              style: const TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche une image réseau avec un repli visuel propre (pas de carré cassé).
class ImageCatalogue extends StatelessWidget {
  const ImageCatalogue({
    super.key,
    required this.url,
    required this.icone,
    this.rayon = Rayons.carte,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final IconData icone;
  final double rayon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final adresse = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Pal.surfaceHaute),
        child: (adresse == null || adresse.isEmpty)
            ? Center(child: Icon(icone, color: Pal.texteDoux, size: 22))
            : Image.network(
                adresse,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                // Une image distante qui échoue (hors ligne, 404) ne casse
                // jamais la mise en page.
                errorBuilder: (_, __, ___) =>
                    Center(child: Icon(icone, color: Pal.texteDoux, size: 22)),
                loadingBuilder: (context, enfant, progression) {
                  if (progression == null) return enfant;
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Pal.texteDoux),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Petit badge (catégorie, premium, stock).
class Etiquette extends StatelessWidget {
  const Etiquette({
    super.key,
    required this.texte,
    this.couleur = Pal.texteDoux,
    this.icone,
  });

  final String texte;
  final Color couleur;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espace.s, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withAlpha(28),
        borderRadius: BorderRadius.circular(Rayons.pilule),
        border: Border.all(color: couleur.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 11, color: couleur),
            const SizedBox(width: 3),
          ],
          Text(
            texte,
            style: TextStyle(fontSize: 10, color: couleur, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
