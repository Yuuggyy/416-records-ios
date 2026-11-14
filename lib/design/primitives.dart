import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Filet horizontal : la seule « décoration » autorisée.
class Filet extends StatelessWidget {
  const Filet({super.key, this.couleur, this.epaisseur = 1});

  final Color? couleur;
  final double epaisseur;

  @override
  Widget build(BuildContext context) => Container(
        height: epaisseur,
        color: couleur ?? Pal.filet,
      );
}

/// Étiquette de section : numéro, intitulé, éventuellement une action.
class EtiquetteSection extends StatelessWidget {
  const EtiquetteSection({
    super.key,
    required this.numero,
    required this.titre,
    this.action,
    this.onAction,
  });

  final String numero;
  final String titre;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Filet(),
        const SizedBox(height: Espace.s),
        Row(
          children: [
            Text('$numero /', style: Typo.etiquette.copyWith(color: Pal.primaire)),
            const SizedBox(width: Espace.s),
            Expanded(child: Text(titre.toUpperCase(), style: Typo.etiquette)),
            if (action != null)
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  action!.toUpperCase(),
                  style: Typo.etiquette.copyWith(color: Pal.texte, letterSpacing: 1.2),
                ),
              ),
          ],
        ),
        const SizedBox(height: Espace.s),
      ],
    );
  }
}

/// Affiche : image pleine largeur, angle net, legende en bas.
class Affiche extends StatelessWidget {
  const Affiche({
    super.key,
    required this.image,
    required this.titre,
    required this.meta,
    this.surnom,
    this.onTap,
    this.hauteur = 220,
    this.largeur,
  });

  final String? image;
  final String titre;
  final String meta;
  final String? surnom;
  final VoidCallback? onTap;
  final double hauteur;
  final double? largeur;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: largeur,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Rayons.carte),
              child: SizedBox(
                height: hauteur,
                width: largeur ?? double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null && image!.isNotEmpty)
                      Image.network(
                        image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Pal.surfaceHaute),
                      )
                    else
                      Container(color: Pal.surfaceHaute),
                    // Voile bas : lisibilité du titre sans dégradé voyant.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: hauteur * 0.55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Pal.fond.withAlpha(0), Pal.fond.withAlpha(232)],
                          ),
                        ),
                      ),
                    ),
                    if (surnom != null)
                      Positioned(
                        left: Espace.s,
                        top: Espace.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          color: Pal.primaire,
                          child: Text(
                            surnom!,
                            style: Typo.etiquette.copyWith(color: Pal.texte, fontSize: 9),
                          ),
                        ),
                      ),
                    Positioned(
                      left: Espace.m,
                      right: Espace.m,
                      bottom: Espace.m,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Typo.sousTitre.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 4),
                          Text(meta, style: Typo.meta),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'index : numéro, nom, précision, chevron. Pas de pastille ronde.
class LigneIndex extends StatelessWidget {
  const LigneIndex({
    super.key,
    required this.numero,
    required this.titre,
    required this.detail,
    this.image,
    this.onTap,
  });

  final String numero;
  final String titre;
  final String detail;
  final String? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const Filet(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Espace.m),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(numero, style: Typo.etiquette.copyWith(color: Pal.texteDoux)),
                ),
                if (image != null && image!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: Espace.m),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.network(
                        image!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Pal.surfaceHaute),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: const TextStyle(fontFamily: Typo.texte, fontSize: 15, fontWeight: FontWeight.w600, color: Pal.texte)),
                      const SizedBox(height: 2),
                      Text(detail.toUpperCase(), style: Typo.meta.copyWith(fontSize: 10)),
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

/// Apparition sobre : fondu et glissement court, une seule fois.
class EntreeAnimee extends StatefulWidget {
  const EntreeAnimee({super.key, required this.child, this.delai = Duration.zero});

  final Widget child;
  final Duration delai;

  @override
  State<EntreeAnimee> createState() => _EntreeAnimeeState();
}

class _EntreeAnimeeState extends State<EntreeAnimee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delai, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courbe = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: courbe,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(courbe),
        child: widget.child,
      ),
    );
  }
}
