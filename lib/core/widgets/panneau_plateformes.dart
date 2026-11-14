import 'package:flutter/material.dart';

import '../liens_ecoute.dart';
import '../theme.dart';
import 'logos_plateformes.dart';

/// Ouvre un panneau listant les plateformes où ce morceau existe.
Future<void> montrerPlateformes(BuildContext context, {required String titre, required List<LienEcoute> liens}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Pal.surface,
    showDragHandle: true,
    builder: (ctx) => PanneauPlateformes(titre: titre, liens: liens),
  );
}

class PanneauPlateformes extends StatelessWidget {
  const PanneauPlateformes({super.key, required this.titre, required this.liens});

  final String titre;
  final List<LienEcoute> liens;

  Future<void> _ouvrir(BuildContext context, LienEcoute lien) async {
    final ok = await ouvrirEcoute(lien);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Impossible d\'ouvrir ${lien.plateforme.libelle}.'),
          backgroundColor: Pal.surfaceHaute,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Écouter sur', style: TextStyle(fontSize: 12, color: Pal.texteDoux)),
            const SizedBox(height: 2),
            Text(titre, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: Espace.m),
            if (liens.isEmpty)
              const Text('Pas encore disponible sur d\'autres plateformes.',
                  style: TextStyle(fontSize: 13, color: Pal.texteDoux))
            else
              ...liens.map((lien) => Padding(
                    padding: const EdgeInsets.only(bottom: Espace.s),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: ValueKey('plateforme-${lien.plateforme.name}'),
                        onPressed: () => _ouvrir(context, lien),
                        style: FilledButton.styleFrom(
                          backgroundColor: couleurPlateforme(lien.plateforme),
                          foregroundColor: texteSurPlateforme(lien.plateforme),
                          minimumSize: const Size(0, 46),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LogoPlateforme(lien.plateforme, taille: 18, couleur: texteSurPlateforme(lien.plateforme)),
                            const SizedBox(width: 10),
                            Text(lien.plateforme.libelle),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
