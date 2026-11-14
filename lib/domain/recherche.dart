import 'models/artiste.dart';
import 'models/film.dart';
import 'models/morceau.dart';
import 'models/produit.dart';

/// Nature d'un résultat de recherche.
enum TypeResultat {
  artiste('Artiste'),
  morceau('Morceau'),
  film('Film'),
  produit('Merch');

  const TypeResultat(this.libelle);
  final String libelle;
}

/// Un résultat, prêt à afficher : le titre, une précision, et l'objet d'origine
/// pour ouvrir la bonne fiche.
class ResultatRecherche {
  const ResultatRecherche({
    required this.type,
    required this.titre,
    required this.detail,
    required this.score,
    this.imageUrl,
    this.artiste,
    this.morceau,
    this.film,
    this.produit,
  });

  final TypeResultat type;
  final String titre;
  final String detail;
  final int score;
  final String? imageUrl;
  final Artiste? artiste;
  final Morceau? morceau;
  final Film? film;
  final Produit? produit;
}

/// Tout ce qui peut être trouvé, chargé une fois puis filtré en mémoire.
class IndexRecherche {
  const IndexRecherche({
    this.artistes = const [],
    this.morceaux = const [],
    this.films = const [],
    this.produits = const [],
  });

  final List<Artiste> artistes;
  final List<Morceau> morceaux;
  final List<Film> films;
  final List<Produit> produits;

  bool get vide =>
      artistes.isEmpty && morceaux.isEmpty && films.isEmpty && produits.isEmpty;
}

/// Met un texte en minuscules, sans accents ni ponctuation, pour que
/// « Kinshasa Nights », « kinshasa nights » et « KINSHASÀ  nights » se valent.
String normaliser(String texte) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };
  final bas = texte.toLowerCase();
  final sortie = StringBuffer();
  for (final rune in bas.runes) {
    final lettre = String.fromCharCode(rune);
    sortie.write(accents[lettre] ?? lettre);
  }
  return sortie.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Moteur de recherche du catalogue.
///
/// Chaque mot saisi doit se retrouver quelque part dans l'élément (recherche
/// « ET »), dans n'importe lequel de ses champs. Le score favorise le champ
/// principal (nom, titre) sur les champs secondaires (genre, ville,
/// description), et un mot entier ou en début de mot sur un fragment.
class MoteurRecherche {
  const MoteurRecherche();

  /// Nombre maximal de résultats renvoyés.
  static const int limite = 60;

  List<ResultatRecherche> chercher(IndexRecherche index, String requete) {
    final mots =
        normaliser(requete).split(' ').where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return const [];

    final resultats = <ResultatRecherche>[];

    for (final artiste in index.artistes) {
      final score = _score(
        mots,
        principal: [artiste.nom],
        secondaires: [artiste.genre, artiste.ville, artiste.bio, 'artiste'],
      );
      if (score > 0) {
        resultats.add(ResultatRecherche(
          type: TypeResultat.artiste,
          titre: artiste.nom,
          detail: _joindre([artiste.genre, artiste.ville]),
          score: score,
          imageUrl: artiste.photoUrl,
          artiste: artiste,
        ));
      }
    }

    for (final morceau in index.morceaux) {
      final score = _score(
        mots,
        principal: [morceau.titre],
        secondaires: [
          morceau.artisteNom,
          if (morceau.annee != null) '${morceau.annee}',
          'morceau son titre musique',
        ],
      );
      if (score > 0) {
        resultats.add(ResultatRecherche(
          type: TypeResultat.morceau,
          titre: morceau.titre,
          detail: _joindre([
            morceau.artisteNom,
            morceau.dureeLisible == '—' ? '' : morceau.dureeLisible,
          ]),
          score: score,
          imageUrl: morceau.posterUrl,
          morceau: morceau,
        ));
      }
    }

    for (final film in index.films) {
      final score = _score(
        mots,
        principal: [film.titre],
        secondaires: [
          film.genre,
          film.libelleCategorie,
          film.categorie.cle,
          film.synopsis,
          if (film.annee != null) '${film.annee}',
          ...film.artistes.map((a) => a.nom),
        ],
      );
      if (score > 0) {
        resultats.add(ResultatRecherche(
          type: TypeResultat.film,
          titre: film.titre,
          detail: _joindre([
            film.libelleCategorie,
            film.genre,
            if (film.annee != null) '${film.annee}',
          ]),
          score: score,
          imageUrl: film.afficheUrl ?? film.backdropUrl,
          film: film,
        ));
      }
    }

    for (final produit in index.produits) {
      final score = _score(
        mots,
        principal: [produit.nom],
        secondaires: [
          produit.categorie,
          produit.description,
          produit.artisteNom,
          ...produit.tailles,
          'merch boutique',
        ],
      );
      if (score > 0) {
        resultats.add(ResultatRecherche(
          type: TypeResultat.produit,
          titre: produit.nom,
          detail: _joindre([produit.categorie, produit.prixLisible]),
          score: score,
          imageUrl: produit.imageUrl,
          produit: produit,
        ));
      }
    }

    resultats.sort((a, b) {
      final parScore = b.score.compareTo(a.score);
      if (parScore != 0) return parScore;
      return normaliser(a.titre).compareTo(normaliser(b.titre));
    });
    return resultats.length > limite ? resultats.sublist(0, limite) : resultats;
  }

  /// 0 si un mot manque ; sinon la somme des points de chaque mot.
  int _score(
    List<String> mots, {
    required List<String> principal,
    required List<String> secondaires,
  }) {
    final champsPrincipaux =
        principal.map(normaliser).where((c) => c.isNotEmpty).toList();
    final champsSecondaires =
        secondaires.map(normaliser).where((c) => c.isNotEmpty).toList();

    var total = 0;
    for (final mot in mots) {
      final points = _pointsDuMot(mot, champsPrincipaux, champsSecondaires);
      if (points == 0) return 0;
      total += points;
    }

    // Bonus : la requête entière est le début ou la totalité du champ principal.
    final complete = mots.join(' ');
    for (final champ in champsPrincipaux) {
      if (champ == complete) {
        total += 100;
      } else if (champ.startsWith(complete)) {
        total += 40;
      }
    }
    return total;
  }

  int _pointsDuMot(
      String mot, List<String> principaux, List<String> secondaires) {
    var meilleur = 0;
    for (final champ in principaux) {
      final p = _pointsDansChamp(mot, champ, base: 30);
      if (p > meilleur) meilleur = p;
    }
    for (final champ in secondaires) {
      final p = _pointsDansChamp(mot, champ, base: 10);
      if (p > meilleur) meilleur = p;
    }
    return meilleur;
  }

  int _pointsDansChamp(String mot, String champ, {required int base}) {
    if (!champ.contains(mot)) return 0;
    final mots = champ.split(' ');
    if (mots.contains(mot)) return base + 6; // mot entier
    if (mots.any((m) => m.startsWith(mot))) return base + 3; // début de mot
    return base; // au milieu d'un mot
  }

  String _joindre(List<String> parties) =>
      parties.where((p) => p.trim().isNotEmpty).join(' · ');
}
