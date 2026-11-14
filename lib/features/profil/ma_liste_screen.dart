import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../state/ma_liste.dart';
import '../films/film_screen.dart';

/// Les films mis de côté par l'utilisateur, sur cet appareil.
class MaListeScreen extends StatelessWidget {
  const MaListeScreen({super.key});

  Future<void> _ouvrir(BuildContext context, FilmEnListe entree) async {
    final depot = CatalogueScope.lire(context).depot;
    try {
      final resultat = await depot.film(entree.identifiant);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FilmScreen(film: resultat.donnees)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce film n\'est pas disponible pour le moment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = MaListe.instance..initialiser();
    return Scaffold(
      appBar: AppBar(title: const Text('Ma liste')),
      body: AnimatedBuilder(
        animation: liste,
        builder: (context, _) {
          final films = liste.films;
          if (!liste.charge) return const EtatChargement(message: 'Ouverture de ma liste…');
          if (films.isEmpty) {
            return const EtatVide(
              message: 'Ta liste est vide.',
              details: 'Ouvre un film et touche « Ajouter à ma liste ».',
              icone: Icons.bookmark_border,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Espace.m),
            itemCount: films.length,
            separatorBuilder: (_, __) => const SizedBox(height: Espace.s),
            itemBuilder: (context, i) {
              final f = films[i];
              return Dismissible(
                key: ValueKey(f.identifiant),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: Espace.l),
                  color: Pal.danger,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => liste.retirer(f.identifiant),
                child: InkWell(
                  onTap: () => _ouvrir(context, f),
                  child: Container(
                    padding: const EdgeInsets.all(Espace.s),
                    decoration: BoxDecoration(
                      color: Pal.surface,
                      borderRadius: BorderRadius.circular(Rayons.carte),
                      border: Border.all(color: Pal.bordure),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          height: 76,
                          child: ImageCatalogue(url: f.affiche, icone: Icons.movie_outlined, rayon: 4),
                        ),
                        const SizedBox(width: Espace.m),
                        Expanded(
                          child: Text(
                            f.titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Pal.texteDoux),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
