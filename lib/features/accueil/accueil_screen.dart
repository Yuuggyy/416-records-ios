import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../design/primitives.dart';
import '../../domain/depot_catalogue.dart';
import '../../domain/models/artiste.dart';
import '../../domain/models/film.dart';
import '../../domain/models/produit.dart';
import '../artistes/artiste_screen.dart';
import '../artistes/artistes_screen.dart';
import '../films/film_screen.dart';
import '../films/films_screen.dart';
import '../merch/merch_screen.dart';
import '../merch/produit_screen.dart';
import '../recherche/recherche_screen.dart';

/// Accueil — une page de sommaire de magazine, pas un tableau de bord.
///
/// L'ordre de lecture est explicite : manchette, contenu à la une, puis les
/// trois rayons du label numérotés. Rien n'est encadré sans raison.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  Future<_Accueil>? _avenir;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avenir ??= _charger();
  }

  Future<_Accueil> _charger() async {
    final depot = CatalogueScope.lire(context).depot;
    final films = await depot.filmsEnVedette(limite: 6);
    final catalogue = await depot.films();
    final artistes = await depot.artistes();
    final produits = await depot.produits();

    return _Accueil(
      totalFilms: catalogue.donnees.length,
      totalArtistes: artistes.donnees.length,
      totalProduits: produits.donnees.length,
      films: films.donnees,
      origine: films.origine,
      artistes: artistes.donnees.take(5).toList(),
      produits: produits.donnees
          .where((produit) => produit.vedette || produit.enStock)
          .take(6)
          .toList(),
    );
  }

  void _rafraichir() => setState(() => _avenir = _charger());

  void _ouvrir(Widget ecran) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.fond,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_Accueil>(
          future: _avenir,
          builder: (context, instantane) {
            if (instantane.connectionState != ConnectionState.done) {
              return const EtatChargement(
                  message: 'Ouverture du catalogue 416…');
            }
            if (instantane.hasError) {
              return EtatErreur(
                message: 'Le catalogue n\'a pas pu être ouvert.',
                details: '${instantane.error}',
                onReessayer: _rafraichir,
              );
            }

            final donnees = instantane.data;
            if (donnees == null) {
              return EtatErreur(
                message: 'Catalogue vide.',
                details: 'Aucune donnée reçue.',
                onReessayer: _rafraichir,
              );
            }

            return RefreshIndicator(
              color: Pal.primaire,
              backgroundColor: Pal.surface,
              onRefresh: () async {
                _rafraichir();
                await _avenir;
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _Manchette(),
                  _BarreRecherche(
                      onTap: () => _ouvrir(const RechercheScreen())),
                  if (donnees.origine.horsLigne)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Espace.m),
                      child: BandeauOrigine(origine: OrigineDonnees.reseau),
                    ),
                  _Une(
                    film: donnees.films.isNotEmpty ? donnees.films.first : null,
                    onTap: donnees.films.isEmpty
                        ? null
                        : () => _ouvrir(FilmScreen(film: donnees.films.first)),
                  ),
                  _Section(
                    numero: '01',
                    titre: 'Films',
                    action: 'Tout voir',
                    onAction: () => _ouvrir(const FilmsScreen()),
                    child: donnees.films.isEmpty
                        ? const _Vide(
                            texte: 'Aucun film publié pour le moment.')
                        : SizedBox(
                            height: 268,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Espace.m),
                              itemCount: donnees.films.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: Espace.m),
                              itemBuilder: (context, i) {
                                final film = donnees.films[i];
                                return Affiche(
                                  largeur: 156,
                                  hauteur: 216,
                                  image: film.afficheUrl ?? film.backdropUrl,
                                  titre: film.titre,
                                  meta: film.ficheTechnique,
                                  surnom: film.premium ? 'PREMIUM' : null,
                                  onTap: () => _ouvrir(FilmScreen(film: film)),
                                );
                              },
                            ),
                          ),
                  ),
                  _Section(
                    numero: '02',
                    titre: 'Artistes',
                    action: 'Tous',
                    onAction: () => _ouvrir(const ArtistesScreen()),
                    child: donnees.artistes.isEmpty
                        ? const _Vide(texte: 'Aucun artiste publié.')
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Espace.m),
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < donnees.artistes.length;
                                    i++)
                                  LigneIndex(
                                    numero: (i + 1).toString().padLeft(2, '0'),
                                    titre: donnees.artistes[i].nom,
                                    detail: donnees.artistes[i].genre.isEmpty
                                        ? donnees.artistes[i].ville
                                        : '${donnees.artistes[i].genre} · ${donnees.artistes[i].ville}',
                                    image: donnees.artistes[i].photoUrl,
                                    onTap: () => _ouvrir(
                                      FicheArtisteRoute(
                                          artiste: donnees.artistes[i]),
                                    ),
                                  ),
                                const Filet(),
                              ],
                            ),
                          ),
                  ),
                  _Section(
                    numero: '03',
                    titre: 'Boutique',
                    action: 'Voir le merch',
                    onAction: () => _ouvrir(const MerchScreen()),
                    child: donnees.produits.isEmpty
                        ? const _Vide(texte: 'Boutique en préparation.')
                        : SizedBox(
                            height: 240,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Espace.m),
                              itemCount: donnees.produits.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: Espace.m),
                              itemBuilder: (context, i) {
                                final produit = donnees.produits[i];
                                return Affiche(
                                  largeur: 150,
                                  hauteur: 176,
                                  image: produit.imageUrl,
                                  titre: produit.nom,
                                  meta: produit.prixLisible,
                                  onTap: () =>
                                      _ouvrir(ProduitScreen(produit: produit)),
                                );
                              },
                            ),
                          ),
                  ),
                  const _PiedDePage(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fausse barre de recherche : un toucher ouvre l'écran de recherche, où le
/// clavier s'ouvre tout de suite. Évite un champ vivant dans une liste qui
/// défile.
class _BarreRecherche extends StatelessWidget {
  const _BarreRecherche({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.l),
      child: Semantics(
        button: true,
        label: 'Rechercher dans le catalogue',
        child: InkWell(
          key: const ValueKey('barre-recherche'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(Rayons.champ),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Espace.m),
            decoration: BoxDecoration(
              color: Pal.surface,
              borderRadius: BorderRadius.circular(Rayons.champ),
              border: Border.all(color: Pal.bordure),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 20, color: Pal.texteDoux),
                SizedBox(width: Espace.s + 2),
                Expanded(
                  child: Text(
                    'Artiste, morceau, film, merch…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: Typo.texte, fontSize: 14.5, color: Pal.texteDoux),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Manchette : l'identité du label et sa phrase d'accroche, sans compteurs.
class _Manchette extends StatelessWidget {
  const _Manchette();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Espace.m, Espace.m, Espace.m, Espace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/branding/logo-416-transparent.png',
                height: 30,
                filterQuality: FilterQuality.high,
                semanticLabel: '416 Records',
              ),
              const SizedBox(width: Espace.m),
              const Expanded(
                child: Text('N° 001 · KINSHASA',
                    textAlign: TextAlign.right, style: Typo.etiquette),
              ),
            ],
          ),
          const SizedBox(height: Espace.l),
          const Text('LE LABEL\nDE LA VILLE.', style: Typo.titre),
          const SizedBox(height: Espace.m),
          const Text(
            'Films, artistes et merch d\'un label indépendant de Kinshasa. '
            'Le catalogue, sans détour.',
            style: Typo.corps,
          ),
          const SizedBox(height: Espace.l),
        ],
      ),
    );
  }
}

/// Contenu à la une : image pleine largeur, légende dessous, pas de surcouche.
class _Une extends StatelessWidget {
  const _Une({this.film, this.onTap});

  final Film? film;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = film;
    if (f == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            width: double.infinity,
            child: f.backdropUrl != null && f.backdropUrl!.isNotEmpty
                ? Image.network(
                    f.backdropUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Pal.surfaceHaute),
                  )
                : (f.afficheUrl != null
                    ? Image.network(
                        f.afficheUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Pal.surfaceHaute),
                      )
                    : Container(color: Pal.surfaceHaute)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Espace.m, Espace.m, Espace.m, Espace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('À LA UNE',
                        style: Typo.etiquette.copyWith(color: Pal.primaire)),
                    const SizedBox(width: Espace.s),
                    Expanded(
                        child: Text(f.libelleCategorie.toUpperCase(),
                            style: Typo.etiquette)),
                  ],
                ),
                const SizedBox(height: Espace.s),
                Text(f.titre, style: Typo.titre.copyWith(fontSize: 28)),
                const SizedBox(height: Espace.s),
                Text(f.synopsis,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.corps),
                const SizedBox(height: Espace.m),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Espace.m, vertical: Espace.s),
                      decoration: BoxDecoration(
                        border: Border.all(color: Pal.texte),
                        borderRadius: BorderRadius.circular(Rayons.champ),
                      ),
                      child: Text(
                        'OUVRIR LA FICHE',
                        style: Typo.etiquette.copyWith(color: Pal.texte),
                      ),
                    ),
                    const SizedBox(width: Espace.m),
                    Flexible(child: Text(f.ficheTechnique, style: Typo.meta)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rayon numéroté : étiquette, contenu, filet de séparation.
class _Section extends StatelessWidget {
  const _Section({
    required this.numero,
    required this.titre,
    required this.child,
    this.action,
    this.onAction,
  });

  final String numero;
  final String titre;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espace.m),
          child: EtiquetteSection(
              numero: numero, titre: titre, action: action, onAction: onAction),
        ),
        child,
        const SizedBox(height: Espace.xl),
      ],
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Espace.m, vertical: Espace.s),
        child: Text(texte, style: Typo.corps),
      );
}

class _PiedDePage extends StatelessWidget {
  const _PiedDePage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Filet(),
          SizedBox(height: Espace.m),
          Text('416 RECORDS — KINSHASA, RDC', style: Typo.etiquette),
          SizedBox(height: Espace.s),
          Text('Inspire by YuuStore · +243 977 555 768', style: Typo.meta),
        ],
      ),
    );
  }
}

class _Accueil {
  const _Accueil({
    required this.totalFilms,
    required this.totalArtistes,
    required this.totalProduits,
    required this.films,
    required this.origine,
    required this.artistes,
    required this.produits,
  });

  final int totalFilms;
  final int totalArtistes;
  final int totalProduits;
  final List<Film> films;
  final OrigineDonnees origine;
  final List<Artiste> artistes;
  final List<Produit> produits;
}
