import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../abonnement/offres_screen.dart';
import 'duree_pub.dart';
import 'ecran_pub.dart';

/// Résultat du choix « Super fan ».
enum ChoixSuperFan { abonne, pubRegardee, annule }

/// Fenêtre « Super fan » pour un non-abonné : payer pour un mois sans pub,
/// ou regarder une pub (avec un mini-jeu) puis accéder au contenu.
///
/// Un abonné ne la voit jamais : on lui rend `abonne` tout de suite.
Future<ChoixSuperFan> demanderSuperFan(
  BuildContext context, {
  required TypeContenu type,
  int? dureeContenuMinutes,
}) async {
  final catalogue = context.getInheritedWidgetOfExactType<CatalogueScope>();
  // Sans catalogue (cas de test isolé), aucune vérification possible : on laisse passer.
  if (catalogue == null || catalogue.abonnement.abonne) return ChoixSuperFan.abonne;

  final choix = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Pal.surface,
    isScrollControlled: true,
    builder: (c) => _FeuilleChoix(type: type, dureeContenuMinutes: dureeContenuMinutes),
  );
  if (choix == null || !context.mounted) return ChoixSuperFan.annule;

  if (choix == 'payer') {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => const OffresScreen()));
    if (!context.mounted) return ChoixSuperFan.annule;
    final abonnement = catalogue.abonnement;
    await abonnement.rafraichir();
    return abonnement.abonne ? ChoixSuperFan.abonne : ChoixSuperFan.annule;
  }

  final duree = dureePubSecondes(type, dureeContenuMinutes: dureeContenuMinutes);
  final vue = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => EcranPub(dureeSecondes: duree),
    ),
  );
  return vue == true ? ChoixSuperFan.pubRegardee : ChoixSuperFan.annule;
}

class _FeuilleChoix extends StatelessWidget {
  const _FeuilleChoix({required this.type, this.dureeContenuMinutes});

  final TypeContenu type;
  final int? dureeContenuMinutes;

  @override
  Widget build(BuildContext context) {
    final duree = dureePubSecondes(type, dureeContenuMinutes: dureeContenuMinutes);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Espace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Super fan', style: TextStyle(fontFamily: Typo.affiche, fontSize: 24)),
            const SizedBox(height: Espace.s),
            const Text(
              'Deux façons d\u2019y accéder.',
              style: TextStyle(color: Pal.texteDoux, fontSize: 14),
            ),
            const SizedBox(height: Espace.l),
            FilledButton(
              key: const ValueKey('payer'),
              onPressed: () => Navigator.pop(context, 'payer'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('PAYER 1,25 \$ : PREMIUM UN MOIS, SANS PUB'),
              ),
            ),
            const SizedBox(height: Espace.s),
            OutlinedButton(
              key: const ValueKey('pub'),
              onPressed: () => Navigator.pop(context, 'pub'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('REGARDER UNE PUB ($duree S) AVEC UN JEU'),
              ),
            ),
            const SizedBox(height: Espace.s),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('PLUS TARD'),
            ),
          ],
        ),
      ),
    );
  }
}
