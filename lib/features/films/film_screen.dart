import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/cartes.dart';
import '../../core/widgets/etats.dart';
import '../../domain/models/artiste.dart';
import '../../domain/depot_abonnement.dart';
import '../../domain/models/film.dart';
import '../abonnement/offres_screen.dart';
import '../../state/ma_liste.dart';
import '../lecteur/lecteur_screen.dart';
import '../pubs/choix_super_fan.dart';
import '../pubs/duree_pub.dart';
import '../artistes/artiste_screen.dart';

/// Fiche film : visuel d'ambiance, fiche technique, synopsis, artistes, lien
/// vidéo et films du même univers.
class FilmScreen extends StatefulWidget {
  const FilmScreen({super.key, required this.film});

  /// Film déjà connu de la liste : affiché immédiatement, puis rafraîchi en
  /// arrière-plan avec la fiche complète de l'API.
  final Film film;

  @override
  State<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends State<FilmScreen> {
  late Film _film = widget.film;
  bool _rafraichissement = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _completer();
  }

  Future<void> _completer() async {
    if (_rafraichissement) return;
    _rafraichissement = true;
    final depot = CatalogueScope.lire(context).depot;
    try {
      final resultat = await depot.film(widget.film.identifiant);
      if (!mounted) return;
      setState(() => _film = resultat.donnees);
    } catch (_) {
      // La fiche passée en argument reste affichée : pas d'écran d'erreur
      // pour un simple rafraîchissement raté.
    }
  }

  void _ouvrirArtiste(Artiste artiste) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FicheArtisteRoute(artiste: artiste)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final film = _film;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Pal.fond,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ImageCatalogue(
                    url: film.backdropUrl ?? film.afficheUrl,
                    icone: Icons.movie_outlined,
                    rayon: 0,
                  ),
                  // Dégradé vers le fond : le titre reste lisible.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22040406), Color(0x00040406), Pal.fond],
                        stops: [0, 0.55, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Espace.m, 0, Espace.m, Espace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    film.titre,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: Espace.s),
                  Wrap(
                    spacing: Espace.xs,
                    runSpacing: Espace.xs,
                    children: [
                      Etiquette(texte: film.libelleCategorie, couleur: Pal.primaireClaire),
                      if (film.premium)
                        const Etiquette(texte: 'PREMIUM', couleur: Pal.alerte, icone: Icons.lock_outline),
                      if (film.vedette)
                        const Etiquette(texte: 'SÉLECTION', couleur: Pal.succes, icone: Icons.star_border),
                    ],
                  ),
                  const SizedBox(height: Espace.m),
                  if (film.ficheTechnique.isNotEmpty)
                    Text(
                      film.ficheTechnique,
                      style: const TextStyle(fontSize: 12, color: Pal.texteDoux),
                    ),
                  const SizedBox(height: Espace.l),
                  if (film.synopsis.isNotEmpty) ...[
                    const _SousTitre('Synopsis'),
                    const SizedBox(height: Espace.s),
                    Text(
                      film.synopsis,
                      style: const TextStyle(fontSize: 14, color: Pal.texte, height: 1.55),
                    ),
                    const SizedBox(height: Espace.l),
                  ],
                  if (film.premium)
                    _BlocPremium(film: film)
                  else if (film.videoUrl != null)
                    _BoutonLecture(film: film, url: film.videoUrl!),
                  if (film.premium || film.videoUrl != null) const SizedBox(height: Espace.m),
                  _BoutonMaListe(film: film),
                  const SizedBox(height: Espace.l),
                  if (film.artistes.isNotEmpty) ...[
                    const _SousTitre('Artistes'),
                    const SizedBox(height: Espace.s),
                    ...film.artistes.map(
                      (artiste) => Padding(
                        padding: const EdgeInsets.only(bottom: Espace.s),
                        child: CarteArtiste(artiste: artiste, onTap: () => _ouvrirArtiste(artiste)),
                      ),
                    ),
                  ],
                  const SizedBox(height: Espace.m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SousTitre extends StatelessWidget {
  const _SousTitre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: const TextStyle(fontSize: 11, letterSpacing: 1.6, color: Pal.texteDoux, fontWeight: FontWeight.w600),
    );
  }
}

/// Lecture d'un film libre : le serveur fournit déjà le lien, le lecteur
/// natif l'ouvre. Sans lien publié, le bouton l'indique au lieu de rester muet.
class _BoutonLecture extends StatelessWidget {
  const _BoutonLecture({required this.film, required this.url});

  final Film film;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Rayons.carte),
      onTap: () async {
        // Film libre : un non-abonné choisit entre payer et une pub avec jeu.
        final res = await demanderSuperFan(
          context,
          type: TypeContenu.video,
          dureeContenuMinutes: film.dureeMinutes,
        );
        if (res == ChoixSuperFan.annule || !context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LecteurScreen(
              titre: film.titre,
              sousTitre: film.categorieLibelle,
              source: url,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(Espace.m),
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(Rayons.carte),
          border: Border.all(color: Pal.bordure),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pal.primaire.withAlpha(48),
                borderRadius: BorderRadius.circular(Rayons.champ),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Pal.primaireClaire),
            ),
            const SizedBox(width: Espace.m),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Regarder', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(
                    'Accès libre, sans abonnement.',
                    style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.35),
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

/// Contenu premium : le bouton interroge le serveur, qui décide.
///
/// L'application n'affirme jamais que l'accès est ouvert : elle envoie la
/// demande à `/api/films/<slug>/lecture/`. Un 402 ouvre l'écran des offres
/// avec le message exact du serveur ; un 200 affiche le lien autorisé.
class _BlocPremium extends StatefulWidget {
  const _BlocPremium({required this.film});

  final Film film;

  @override
  State<_BlocPremium> createState() => _BlocPremiumState();
}

class _BlocPremiumState extends State<_BlocPremium> {
  bool _verification = false;

  Future<void> _verifierAcces() async {
    setState(() => _verification = true);
    final controleur = CatalogueScope.lire(context).abonnement;
    try {
      final lecture = await controleur.lectureFilm(widget.film.identifiant);
      if (!mounted) return;
      setState(() => _verification = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LecteurScreen(
            titre: lecture.titre.isEmpty ? widget.film.titre : lecture.titre,
            sousTitre: widget.film.categorieLibelle,
            source: lecture.urlVideo,
          ),
        ),
      );
    } on AccesRefuse catch (refus) {
      if (!mounted) return;
      setState(() => _verification = false);
      await _ouvrirOffres(refus.message);
    } on ErreurAbonnement catch (erreur) {
      if (!mounted) return;
      setState(() => _verification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erreur.message), backgroundColor: Pal.surfaceHaute),
      );
    }
  }

  Future<void> _ouvrirOffres([String? message]) async {
    final controleur = CatalogueScope.lire(context).abonnement;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OffresScreen(messageBlocage: message)),
    );
    // Retour des offres : l'abonnement a peut-être été activé entre-temps.
    if (mounted) await controleur.rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espace.m),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: Pal.alerte.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, color: Pal.alerte, size: 18),
              SizedBox(width: Espace.s),
              Expanded(
                child: Text(
                  'Réservé aux abonnés 416',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espace.xs),
          const Text(
            'Le film entier demande un abonnement actif. La vérification se fait sur le serveur 416.',
            style: TextStyle(fontSize: 11, color: Pal.texteDoux, height: 1.4),
          ),
          const SizedBox(height: Espace.m),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _verification ? null : _verifierAcces,
                  icon: _verification
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Regarder'),
                ),
              ),
              const SizedBox(width: Espace.s),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _ouvrirOffres(),
                  child: const Text('S\'abonner'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// « Ajouter à ma liste » / « Dans ma liste » : bascule locale, sans compte.
class _BoutonMaListe extends StatelessWidget {
  const _BoutonMaListe({required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    final liste = MaListe.instance;
    return AnimatedBuilder(
      animation: liste,
      builder: (context, _) {
        final dedans = liste.contient(film.identifiant);
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final ajoute = await liste.basculer(film);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(ajoute ? 'Ajouté à ma liste.' : 'Retiré de ma liste.'),
                  backgroundColor: Pal.surfaceHaute,
                ));
            },
            icon: Icon(dedans ? Icons.check : Icons.add, size: 18),
            label: Text(dedans ? 'Dans ma liste' : 'Ajouter à ma liste'),
            style: OutlinedButton.styleFrom(
              foregroundColor: dedans ? Pal.primaireClaire : Pal.texte,
              side: BorderSide(color: dedans ? Pal.primaire : Pal.bordure),
              minimumSize: const Size(0, 44),
            ),
          ),
        );
      },
    );
  }
}
