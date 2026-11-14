import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/liens_ecoute.dart';
import '../../core/scope.dart';
import '../../core/theme.dart';
import '../../core/widgets/etats.dart';
import '../../core/widgets/panneau_plateformes.dart';
import '../../domain/models/morceau.dart';
import '../../domain/recherche.dart';
import '../artistes/artiste_screen.dart';
import '../films/film_screen.dart';
import '../lecteur/lecteur_morceau_screen.dart';
import '../lecteur/lecteur_screen.dart' show QualiteAudio;
import '../merch/produit_screen.dart';

/// Recherche dans tout le catalogue : artistes, morceaux, films, merch.
///
/// L'index est chargé une seule fois à l'ouverture, puis la saisie filtre en
/// mémoire : les résultats suivent la frappe sans requête réseau.
class RechercheScreen extends StatefulWidget {
  const RechercheScreen({super.key, this.indexInitial});

  /// Index fourni d'avance (tests) ; sinon chargé depuis le catalogue.
  final IndexRecherche? indexInitial;

  @override
  State<RechercheScreen> createState() => _RechercheScreenState();
}

class _RechercheScreenState extends State<RechercheScreen> {
  static const _moteur = MoteurRecherche();

  final TextEditingController _champ = TextEditingController();
  final FocusNode _focus = FocusNode();
  Future<IndexRecherche>? _index;
  Timer? _minuteur;
  String _requete = '';
  TypeResultat? _filtre;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _index ??= widget.indexInitial != null
        ? Future.value(widget.indexInitial)
        : _charger();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _champ.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<IndexRecherche> _charger() async {
    final depot = CatalogueScope.lire(context).depot;
    final films = await depot.films();
    final artistes = await depot.artistes();
    final produits = await depot.produits();

    // Les morceaux ne sont exposés que par la fiche de chaque artiste. Un
    // artiste dont la fiche échoue ne doit pas vider toute la recherche.
    final lots = await Future.wait(artistes.donnees.map((artiste) async {
      try {
        final r = await depot.morceaux(artiste.identifiant);
        return r.donnees;
      } catch (_) {
        return <Morceau>[];
      }
    }));

    return IndexRecherche(
      artistes: artistes.donnees,
      morceaux: [for (final lot in lots) ...lot],
      films: films.donnees,
      produits: produits.donnees,
    );
  }

  void _saisie(String texte) {
    _minuteur?.cancel();
    _minuteur = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _requete = texte);
    });
    setState(() {}); // met à jour la croix « effacer » tout de suite
  }

  void _effacer() {
    _champ.clear();
    _minuteur?.cancel();
    setState(() => _requete = '');
    _focus.requestFocus();
  }

  void _ouvrir(ResultatRecherche r) {
    switch (r.type) {
      case TypeResultat.artiste:
        _pousser(FicheArtisteRoute(artiste: r.artiste!));
      case TypeResultat.film:
        _pousser(FilmScreen(film: r.film!));
      case TypeResultat.produit:
        _pousser(ProduitScreen(produit: r.produit!));
      case TypeResultat.morceau:
        _ouvrirMorceau(r.morceau!);
    }
  }

  void _pousser(Widget ecran) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
  }

  bool _plein(String? u) => (u ?? '').trim().isNotEmpty;

  /// Même règle que la fiche artiste : lecteur s'il y a un fichier audio,
  /// sinon les plateformes où écouter le morceau.
  void _ouvrirMorceau(Morceau morceau) {
    final qualites = <QualiteAudio>[
      if (_plein(morceau.audioHqUrl)) QualiteAudio('Super fan', morceau.audioHqUrl),
      if (_plein(morceau.audioUrl)) QualiteAudio('Compressée', morceau.audioUrl),
    ];
    final liens = liensDuMorceau(morceau);
    if (qualites.isNotEmpty) {
      _pousser(LecteurMorceauScreen(
        titre: morceau.titre,
        artiste: morceau.artisteNom,
        posterUrl: morceau.posterUrl,
        paroles: morceau.paroles,
        qualites: qualites,
        liens: liens,
      ));
    } else if (liens.isNotEmpty) {
      montrerPlateformes(context, titre: morceau.titre, liens: liens);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ce morceau n\'est pas encore disponible à l\'écoute.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.fond,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const ValueKey('champ-recherche'),
          controller: _champ,
          focusNode: _focus,
          autofocus: true,
          onChanged: _saisie,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: Typo.texte, fontSize: 16, color: Pal.texte),
          decoration: InputDecoration(
            hintText: 'Artiste, morceau, film, merch…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _champ.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('effacer-recherche'),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Effacer',
                    onPressed: _effacer,
                  ),
          ),
        ),
      ),
      body: FutureBuilder<IndexRecherche>(
        future: _index,
        builder: (context, instantane) {
          if (instantane.connectionState != ConnectionState.done) {
            return const EtatChargement(message: 'Préparation de la recherche…');
          }
          if (instantane.hasError || instantane.data == null) {
            return EtatErreur(
              message: 'La recherche n\'est pas disponible.',
              details: '${instantane.error}',
              onReessayer: () => setState(() => _index = _charger()),
            );
          }
          return _corps(instantane.data!);
        },
      ),
    );
  }

  Widget _corps(IndexRecherche index) {
    if (_requete.trim().isEmpty) {
      return _Invitation(index: index);
    }

    final tous = _moteur.chercher(index, _requete);
    final resultats =
        _filtre == null ? tous : tous.where((r) => r.type == _filtre).toList();

    final compte = <TypeResultat, int>{};
    for (final r in tous) {
      compte[r.type] = (compte[r.type] ?? 0) + 1;
    }

    return Column(
      children: [
        if (tous.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Espace.m, vertical: Espace.xs),
              children: [
                _Filtre(
                  key: const ValueKey('filtre-tout'),
                  libelle: 'Tout ${tous.length}',
                  actif: _filtre == null,
                  onTap: () => setState(() => _filtre = null),
                ),
                for (final type in TypeResultat.values)
                  if ((compte[type] ?? 0) > 0)
                    _Filtre(
                      key: ValueKey('filtre-${type.name}'),
                      libelle: '${type.libelle} ${compte[type]}',
                      actif: _filtre == type,
                      onTap: () => setState(() => _filtre = type),
                    ),
              ],
            ),
          ),
        Expanded(
          child: resultats.isEmpty
              ? _AucunResultat(requete: _requete.trim())
              : ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(Espace.m, Espace.s, Espace.m, Espace.xxl),
                  itemCount: resultats.length,
                  itemBuilder: (context, i) => _LigneResultat(
                    resultat: resultats[i],
                    onTap: () => _ouvrir(resultats[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({super.key, required this.libelle, required this.actif, required this.onTap});

  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Espace.s),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Espace.m),
          decoration: BoxDecoration(
            color: actif ? Pal.primaire : Colors.transparent,
            borderRadius: BorderRadius.circular(Rayons.champ),
            border: Border.all(color: actif ? Pal.primaire : Pal.bordure),
          ),
          child: Text(
            libelle.toUpperCase(),
            style: Typo.etiquette.copyWith(color: actif ? Pal.texte : Pal.texteDoux),
          ),
        ),
      ),
    );
  }
}

class _LigneResultat extends StatelessWidget {
  const _LigneResultat({required this.resultat, required this.onTap});

  final ResultatRecherche resultat;
  final VoidCallback onTap;

  IconData get _icone => switch (resultat.type) {
        TypeResultat.artiste => Icons.person_outline,
        TypeResultat.morceau => Icons.music_note,
        TypeResultat.film => Icons.movie_outlined,
        TypeResultat.produit => Icons.shopping_bag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('resultat-${resultat.type.name}-${resultat.titre}'),
      onTap: onTap,
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Pal.filet),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Espace.s + 2),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ImageCatalogue(
                      url: resultat.imageUrl, icone: _icone, rayon: Rayons.champ),
                ),
                const SizedBox(width: Espace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultat.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: Typo.texte,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Pal.texte),
                      ),
                      if (resultat.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          resultat.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.meta.copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Espace.s),
                Text(resultat.type.libelle.toUpperCase(), style: Typo.etiquette),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({required this.index});

  final IndexRecherche index;

  @override
  Widget build(BuildContext context) {
    final lignes = <String>[
      '${index.artistes.length} artistes',
      '${index.morceaux.length} morceaux',
      '${index.films.length} films',
      '${index.produits.length} articles de merch',
    ];
    return Padding(
      padding: const EdgeInsets.all(Espace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECHERCHE', style: Typo.etiquette),
          const SizedBox(height: Espace.s),
          const Text('Trouve un nom, un titre ou un genre.', style: Typo.sousTitre),
          const SizedBox(height: Espace.m),
          const Text(
            'Essaie un nom d\'artiste, le titre d\'un morceau, un genre comme « rap », '
            'ou un type de merch comme « t-shirt ».',
            style: Typo.corps,
          ),
          const SizedBox(height: Espace.l),
          Text(lignes.join('  ·  ').toUpperCase(), style: Typo.meta),
        ],
      ),
    );
  }
}

class _AucunResultat extends StatelessWidget {
  const _AucunResultat({required this.requete});

  final String requete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Espace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AUCUN RÉSULTAT', style: Typo.etiquette),
          const SizedBox(height: Espace.s),
          Text('Rien pour « $requete ».', style: Typo.sousTitre),
          const SizedBox(height: Espace.m),
          const Text(
            'Vérifie l\'orthographe ou essaie un mot plus court.',
            style: Typo.corps,
          ),
        ],
      ),
    );
  }
}
