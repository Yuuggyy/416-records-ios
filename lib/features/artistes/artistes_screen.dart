import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/cartes.dart';
import '../../core/widgets/etats.dart';
import '../../domain/depot_catalogue.dart';
import '../../domain/models/artiste.dart';
import 'artiste_screen.dart';

/// Liste des artistes du label, avec recherche locale par nom, genre ou ville.
class ArtistesScreen extends StatefulWidget {
  const ArtistesScreen({super.key});

  @override
  State<ArtistesScreen> createState() => _ArtistesScreenState();
}

class _ArtistesScreenState extends State<ArtistesScreen> {
  final TextEditingController _champ = TextEditingController();
  Future<Resultat<List<Artiste>>>? _avenir;
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

  Future<Resultat<List<Artiste>>> _charger() {
    final depot = CatalogueScope.lire(context).depot;
    return depot.artistes(recherche: _champ.text.trim());
  }

  void _rechercherAvecDelai(String _) {
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _avenir = _charger());
    });
  }

  void _relancer() => setState(() => _avenir = _charger());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artistes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.s),
            child: TextField(
              controller: _champ,
              onChanged: _rechercherAvecDelai,
              onSubmitted: (_) => _relancer(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nom, genre, ville…',
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
          Expanded(
            child: FutureBuilder<Resultat<List<Artiste>>>(
              future: _avenir,
              builder: (context, instantane) {
                if (instantane.connectionState != ConnectionState.done) {
                  return const EtatChargement(message: 'Chargement des artistes…');
                }
                if (instantane.hasError) {
                  return EtatErreur(
                    message: 'Impossible de charger les artistes.',
                    details: '${instantane.error}',
                    onReessayer: _relancer,
                  );
                }
                final resultat = instantane.data;
                if (resultat == null) {
                  return EtatErreur(message: 'Réponse vide du catalogue.', onReessayer: _relancer);
                }
                final artistes = resultat.donnees;
                if (artistes.isEmpty) {
                  return EtatVide(
                    message: _champ.text.trim().isEmpty
                        ? 'Aucun artiste publié.'
                        : 'Aucun artiste ne correspond à « ${_champ.text.trim()} ».',
                    details: 'La recherche couvre le nom, le genre et la ville.',
                    icone: Icons.person_search_outlined,
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
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.xl),
                    itemCount: artistes.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: Espace.s),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Row(
                          children: [
                            Text(
                              '${artistes.length} artiste${artistes.length > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 11, color: Pal.texteDoux),
                            ),
                            if (resultat.origine.horsLigne) ...[
                              const SizedBox(width: Espace.s),
                              Etiquette(texte: resultat.origine.libelle, couleur: Pal.alerte),
                            ],
                          ],
                        );
                      }
                      final artiste = artistes[index - 1];
                      return CarteArtiste(
                        artiste: artiste,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => FicheArtisteRoute(artiste: artiste)),
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
