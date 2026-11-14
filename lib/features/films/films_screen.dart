import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/cartes.dart';
import '../../core/widgets/etats.dart';
import '../../domain/depot_catalogue.dart';
import '../../domain/models/film.dart';
import 'film_screen.dart';

/// Liste des films : recherche plein texte et filtres par catégorie.
///
/// La recherche interroge l'API (`?q=`) après une courte temporisation pour ne
/// pas envoyer une requête par frappe.
class FilmsScreen extends StatefulWidget {
  const FilmsScreen({super.key});

  @override
  State<FilmsScreen> createState() => _FilmsScreenState();
}

class _FilmsScreenState extends State<FilmsScreen> {
  final TextEditingController _champ = TextEditingController();
  CategorieFilm? _categorie;
  Future<Resultat<List<Film>>>? _avenir;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avenir ??= _charger();
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<Resultat<List<Film>>> _charger() {
    final depot = CatalogueScope.lire(context).depot;
    return depot.films(recherche: _champ.text, categorie: _categorie);
  }

  void _relancer({bool immediat = true}) {
    if (!mounted) return;
    setState(() {
      _generation++;
      _avenir = _charger();
    });
  }

  /// Temporisation de frappe : 300 ms.
  void _rechercherAvecDelai(String _) async {
    final generation = ++_generation;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || generation != _generation) return;
    setState(() => _avenir = _charger());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Films'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _relancer,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.s),
            child: TextField(
              controller: _champ,
              onChanged: _rechercherAvecDelai,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _relancer(),
              decoration: InputDecoration(
                hintText: 'Titre, synopsis, genre…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _champ.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Effacer',
                        onPressed: () {
                          _champ.clear();
                          _relancer();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Espace.m),
              children: [
                _Puce(
                  libelle: 'Tout',
                  actif: _categorie == null,
                  onTap: () {
                    setState(() => _categorie = null);
                    _relancer();
                  },
                ),
                ...CategorieFilm.values.map(
                  (categorie) => _Puce(
                    libelle: categorie.libelle,
                    actif: _categorie == categorie,
                    onTap: () {
                      setState(() => _categorie = categorie);
                      _relancer();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Espace.s),
          Expanded(
            child: FutureBuilder<Resultat<List<Film>>>(
              future: _avenir,
              builder: (context, instantane) {
                if (instantane.connectionState != ConnectionState.done) {
                  return const EtatChargement(message: 'Chargement des films…');
                }
                if (instantane.hasError) {
                  return EtatErreur(
                    message: 'Impossible de charger les films.',
                    details: '${instantane.error}',
                    onReessayer: _relancer,
                  );
                }
                final resultat = instantane.data;
                if (resultat == null) {
                  return EtatErreur(message: 'Réponse vide du catalogue.', onReessayer: _relancer);
                }
                final films = resultat.donnees;

                if (films.isEmpty) {
                  return EtatVide(
                    message: _champ.text.trim().isEmpty
                        ? 'Aucun film dans cette catégorie.'
                        : 'Aucun film ne correspond à « ${_champ.text.trim()} ».',
                    details: 'Essayez un autre mot-clé ou retirez le filtre de catégorie.',
                    icone: Icons.movie_filter_outlined,
                    action: OutlinedButton(
                      onPressed: () {
                        _champ.clear();
                        setState(() => _categorie = null);
                        _relancer();
                      },
                      child: const Text('Réinitialiser les filtres'),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _relancer(),
                  color: Pal.primaire,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.xl),
                    itemCount: films.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: Espace.s),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Espace.s),
                          child: Row(
                            children: [
                              Text(
                                '${films.length} titre${films.length > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
                              ),
                              if (resultat.origine.horsLigne) ...[
                                const SizedBox(width: Espace.s),
                                Etiquette(texte: resultat.origine.libelle, couleur: Pal.alerte),
                              ],
                            ],
                          ),
                        );
                      }
                      final film = films[index - 1];
                      return LigneFilm(
                        film: film,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => FilmScreen(film: film)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Espace.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rayons.pilule),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: 7),
          decoration: BoxDecoration(
            color: actif ? Pal.primaire : Pal.surfaceHaute,
            borderRadius: BorderRadius.circular(Rayons.pilule),
            border: Border.all(color: actif ? Pal.primaire : Pal.bordure),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: actif ? Colors.white : Pal.texteDoux,
            ),
          ),
        ),
      ),
    );
  }
}
