/// Durée d'une pub selon ce que l'utilisateur veut écouter ou regarder.
///
/// Règle du label : son = 15 s ; clip ou court contenu (moins de 8 min) = 25 s ;
/// film long de 8 à 15 min = 45 s ; au-delà de 15 min = 60 s.
/// Une pub plus longue est acceptable parce qu'un mini-jeu occupe l'attente.
enum TypeContenu { son, video }

int dureePubSecondes(TypeContenu type, {int? dureeContenuMinutes}) {
  if (type == TypeContenu.son) return 15;
  final m = dureeContenuMinutes;
  if (m == null || m < 8) return 25;
  if (m <= 15) return 45;
  return 60;
}
