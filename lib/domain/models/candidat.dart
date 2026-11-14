import 'package:equatable/equatable.dart';

/// Critères de notation du jury (chacun sur 10).
enum CritereJury {
  voix('Voix'),
  presence('Présence scénique'),
  originalite('Originalité'),
  interpretation('Interprétation');

  const CritereJury(this.libelle);
  final String libelle;
}

/// Candidat d'une édition du concours 416 Records.
class Candidat extends Equatable {
  const Candidat({
    required this.id,
    required this.nom,
    required this.ville,
    required this.photoUrl,
    required this.videoUrl,
    this.streams = 0,
    this.votes = 0,
    this.notesJury = const {},
    this.elimine = false,
  });

  final String id;
  final String nom;
  final String ville;
  final String photoUrl;
  final String videoUrl;

  /// Écoutes cumulées (Spotify et plateformes assimilées).
  final int streams;

  /// Votes reçus dans l'application.
  final int votes;

  /// Notes du jury par critère, sur 10. Un critère absent n'est pas compté.
  final Map<CritereJury, double> notesJury;

  final bool elimine;

  /// Moyenne du jury ramenée sur 100. Renvoie null si le jury n'a pas noté.
  double? get noteJurySur100 {
    if (notesJury.isEmpty) return null;
    final total = notesJury.values.fold<double>(0, (a, b) => a + b);
    return (total / notesJury.length) * 10;
  }

  /// Engagement public brut : 50 % écoutes, 50 % votes (brief 416).
  double get engagementBrut => (streams * 0.5) + (votes * 0.5);

  Candidat copieAvec({
    int? streams,
    int? votes,
    Map<CritereJury, double>? notesJury,
    bool? elimine,
  }) {
    return Candidat(
      id: id,
      nom: nom,
      ville: ville,
      photoUrl: photoUrl,
      videoUrl: videoUrl,
      streams: streams ?? this.streams,
      votes: votes ?? this.votes,
      notesJury: notesJury ?? this.notesJury,
      elimine: elimine ?? this.elimine,
    );
  }

  @override
  List<Object?> get props => [id, nom, ville, photoUrl, videoUrl, streams, votes, notesJury, elimine];
}
