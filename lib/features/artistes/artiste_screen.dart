import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/cartes.dart';
import '../../core/widgets/etats.dart';
import '../../domain/depot_catalogue.dart';
import '../../domain/models/artiste.dart';
import '../../domain/models/artiste_detail.dart';
import '../../domain/models/film.dart';
import '../../domain/models/morceau.dart';
import '../../core/liens_ecoute.dart';
import '../../core/widgets/panneau_plateformes.dart';
import '../../core/widgets/logos_plateformes.dart';
import '../../domain/models/produit.dart';
import '../films/film_screen.dart';
import '../lecteur/lecteur_morceau_screen.dart';
import '../lecteur/lecteur_screen.dart' show QualiteAudio;
import '../merch/produit_screen.dart';

/// Fiche artiste : bannière, bio, morceaux et films auxquels il participe.
///
/// Point d'entrée unique de l'application pour cette fiche, afin que la route
/// soit identique depuis l'accueil, la liste et une fiche film.
class FicheArtisteRoute extends StatelessWidget {
  const FicheArtisteRoute({super.key, required this.artiste});

  final Artiste artiste;

  @override
  Widget build(BuildContext context) => ArtisteScreen(artiste: artiste);
}

class ArtisteScreen extends StatefulWidget {
  const ArtisteScreen({super.key, required this.artiste});

  final Artiste artiste;

  @override
  State<ArtisteScreen> createState() => _ArtisteScreenState();
}

class _ArtisteScreenState extends State<ArtisteScreen> {
  Future<Resultat<ArtisteDetail>>? _avenir;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avenir ??= _charger();
  }

  Future<Resultat<ArtisteDetail>> _charger() {
    final depot = CatalogueScope.lire(context).depot;
    return depot.artiste(widget.artiste.identifiant);
  }

  void _relancer() => setState(() => _avenir = _charger());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Resultat<ArtisteDetail>>(
        future: _avenir,
        builder: (context, instantane) {
          final enAttente = instantane.connectionState != ConnectionState.done;
          final detail = instantane.data?.donnees;
          final artiste = detail?.artiste ?? widget.artiste;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Pal.fond,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageCatalogue(
                        url: artiste.coverUrl ?? artiste.photoUrl,
                        icone: Icons.person_outline,
                        rayon: 0,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x33040406),
                              Color(0x55040406),
                              Pal.fond
                            ],
                            stops: [0, 0.6, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Espace.m, Espace.m, Espace.m, Espace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipOval(
                              child: ImageCatalogue(
                                url: artiste.photoUrl,
                                icone: Icons.person_outline,
                                rayon: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: Espace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artiste.nom,
                                  style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  <String>[artiste.genre, artiste.ville]
                                      .where((element) => element.isNotEmpty)
                                      .join(' · '),
                                  style: const TextStyle(
                                      fontSize: 12, color: Pal.texteDoux),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (artiste.bio.isNotEmpty) ...[
                        const SizedBox(height: Espace.m),
                        Text(
                          artiste.bio,
                          style: const TextStyle(
                              fontSize: 13, color: Pal.texte, height: 1.55),
                        ),
                      ],
                      if (enAttente) ...[
                        const SizedBox(height: Espace.m),
                        const EtatChargement(
                            message: 'Chargement de la discographie…'),
                      ] else if (instantane.hasError) ...[
                        const SizedBox(height: Espace.m),
                        EtatErreur(
                          message: 'Discographie indisponible.',
                          details: '${instantane.error}',
                          onReessayer: _relancer,
                        ),
                      ] else if (detail != null) ...[
                        if (instantane.data!.origine.horsLigne) ...[
                          const SizedBox(height: Espace.m),
                          BandeauOrigine(origine: instantane.data!.origine),
                        ],
                        const SizedBox(height: Espace.l),
                        _SectionMorceaux(morceaux: detail.morceaux),
                        // Absent si l'artiste n'a aucune plateforme renseignée.
                        _BarrePlateformes(
                          liens: liensDeLArtiste(artiste),
                          titre: 'Retrouver l\'artiste sur',
                        ),
                        const SizedBox(height: Espace.l),
                        _SectionFilms(films: detail.films),
                        _SectionMerch(
                            produits: detail.produits, artisteNom: artiste.nom),
                        if (detail.vide) ...[
                          const SizedBox(height: Espace.l),
                          const EtatVide(
                            message: 'Rien de publié pour cet artiste.',
                            details:
                                'Les morceaux et les films arrivent prochainement.',
                            icone: Icons.library_music_outlined,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionMorceaux extends StatelessWidget {
  const _SectionMorceaux({required this.morceaux});

  final List<Morceau> morceaux;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Morceaux',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(
              '${morceaux.length}',
              style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
            ),
          ],
        ),
        const SizedBox(height: Espace.s),
        if (morceaux.isEmpty)
          const Text('Aucun morceau publié.',
              style: TextStyle(fontSize: 12, color: Pal.texteDoux))
        else
          ...morceaux.map((morceau) => _LigneMorceau(morceau: morceau)),
      ],
    );
  }
}

class _LigneMorceau extends StatelessWidget {
  const _LigneMorceau({required this.morceau});

  final Morceau morceau;

  bool _plein(String? u) => (u ?? '').trim().isNotEmpty;

  /// Les versions réellement disponibles, la meilleure d'abord.
  List<QualiteAudio> get _qualites => [
        if (_plein(morceau.audioHqUrl))
          QualiteAudio('Super fan', morceau.audioHqUrl),
        if (_plein(morceau.audioUrl))
          QualiteAudio('Compressée', morceau.audioUrl),
      ];

  bool get _aAudio => _qualites.isNotEmpty;

  List<LienEcoute> get _liens => liensDuMorceau(morceau);

  void _plateformes(BuildContext context) =>
      montrerPlateformes(context, titre: morceau.titre, liens: _liens);

  void _jouer(BuildContext context) {
    final qualites = _qualites;
    if (qualites.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LecteurMorceauScreen(
          titre: morceau.titre,
          artiste: morceau.artisteNom,
          posterUrl: morceau.posterUrl,
          paroles: morceau.paroles,
          qualites: qualites,
          liens: liensDuMorceau(morceau),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verrouille = morceau.premium && !_aAudio;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espace.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.champ),
        onTap: _aAudio
            ? () => _jouer(context)
            : (_liens.isNotEmpty ? () => _plateformes(context) : null),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Espace.m, vertical: Espace.s),
          decoration: BoxDecoration(
            color: Pal.surface,
            borderRadius: BorderRadius.circular(Rayons.champ),
            border: Border.all(color: Pal.bordure),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ImageCatalogue(
                            url: morceau.posterUrl,
                            icone: Icons.music_note,
                            rayon: 6),
                        if (_aAudio)
                          const Icon(Icons.play_circle_fill,
                              size: 34, color: Pal.primaire),
                      ],
                    ),
                  ),
                  const SizedBox(width: Espace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          morceau.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            morceau.dureeLisible,
                            if (morceau.annee != null) '${morceau.annee}'
                          ].where((element) => element.isNotEmpty).join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: Pal.texteDoux),
                        ),
                      ],
                    ),
                  ),
                  if (morceau.premium)
                    const Etiquette(
                        texte: 'PREMIUM',
                        couleur: Pal.alerte,
                        icone: Icons.lock_outline),
                  if (_liens.isNotEmpty)
                    IconButton(
                      key: ValueKey('plateformes-${morceau.id}'),
                      tooltip: 'Écouter sur d\'autres plateformes',
                      icon: const Icon(Icons.headphones_outlined, size: 20, color: Pal.texteDoux),
                      onPressed: () => _plateformes(context),
                    ),
                ],
              ),
              if (verrouille)
                const Padding(
                  padding: EdgeInsets.only(top: Espace.s),
                  child: Text(
                    'Écoute réservée aux abonnés.',
                    style: TextStyle(fontSize: 11, color: Pal.texteDoux),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boutons « Écouter sur … » : un par plateforme renseignée, aux couleurs et
/// avec le logo de la marque, deux par ligne.
class _BarrePlateformes extends StatelessWidget {
  const _BarrePlateformes({required this.liens, this.titre});

  final List<LienEcoute> liens;
  final String? titre;

  Future<void> _ouvrir(BuildContext context, LienEcoute lien) async {
    final ok = await ouvrirEcoute(lien);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir ${lien.plateforme.libelle}.'),
            backgroundColor: Pal.surfaceHaute,
          ),
        );
    }
  }

  Widget _bouton(BuildContext context, LienEcoute lien) {
    final fond = couleurPlateforme(lien.plateforme);
    final encre = texteSurPlateforme(lien.plateforme);
    return FilledButton(
      onPressed: () => _ouvrir(context, lien),
      style: FilledButton.styleFrom(
        backgroundColor: fond,
        foregroundColor: encre,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: Espace.s),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoPlateforme(lien.plateforme, taille: 18, couleur: encre),
          const SizedBox(width: 8),
          Flexible(
            child: Text(lien.plateforme.libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (liens.isEmpty) return const SizedBox.shrink();
    final lignes = <Widget>[];
    for (var i = 0; i < liens.length; i += 2) {
      final paire = liens.skip(i).take(2).toList();
      lignes.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : Espace.s),
        child: Row(
          children: [
            Expanded(child: _bouton(context, paire[0])),
            const SizedBox(width: Espace.s),
            // Un nombre impair laisse la dernière moitié vide, sans étirer le bouton.
            Expanded(child: paire.length > 1 ? _bouton(context, paire[1]) : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: Espace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titre != null) ...[
            Text(titre!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: Espace.s),
          ],
          ...lignes,
        ],
      ),
    );
  }
}

class _SectionMerch extends StatelessWidget {
  const _SectionMerch({required this.produits, required this.artisteNom});

  final List<Produit> produits;
  final String artisteNom;

  @override
  Widget build(BuildContext context) {
    if (produits.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Espace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Merch $artisteNom',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              Text('${produits.length}',
                  style: const TextStyle(fontSize: 12, color: Pal.texteDoux)),
            ],
          ),
          const SizedBox(height: Espace.s),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: produits.length,
              separatorBuilder: (_, __) => const SizedBox(width: Espace.m),
              itemBuilder: (context, index) {
                final produit = produits[index];
                return SizedBox(
                  width: 150,
                  child: CarteProduit(
                    produit: produit,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => ProduitScreen(produit: produit)),
                    ),
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

class _SectionFilms extends StatelessWidget {
  const _SectionFilms({required this.films});

  final List<Film> films;

  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('À l\'écran',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${films.length}',
                style: const TextStyle(fontSize: 12, color: Pal.texteDoux)),
          ],
        ),
        const SizedBox(height: Espace.s),
        SizedBox(
          height: 232,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: films.length,
            separatorBuilder: (_, __) => const SizedBox(width: Espace.m),
            itemBuilder: (context, index) {
              final film = films[index];
              return CarteFilm(
                film: film,
                largeur: 130,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => FilmScreen(film: film)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
