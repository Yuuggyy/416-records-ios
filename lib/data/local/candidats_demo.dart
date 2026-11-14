import '../../domain/models/candidat.dart';

/// Effectif de démonstration de l'édition 2026.
/// Remplacé par les données du backend dès que l'API est branchée.
const List<Candidat> candidatsDemo = [
  Candidat(
    id: 'cnd-01',
    nom: 'Merveille K.',
    ville: 'Kinshasa',
    photoUrl: '',
    videoUrl: '',
    streams: 482000,
    votes: 8420,
    notesJury: {
      CritereJury.voix: 9,
      CritereJury.presence: 8.5,
      CritereJury.originalite: 9.5,
      CritereJury.interpretation: 9,
    },
  ),
  Candidat(
    id: 'cnd-02',
    nom: 'Gloire M.',
    ville: 'Lubumbashi',
    photoUrl: '',
    videoUrl: '',
    streams: 610000,
    votes: 6100,
    notesJury: {
      CritereJury.voix: 8,
      CritereJury.presence: 7.5,
      CritereJury.originalite: 8,
      CritereJury.interpretation: 8.5,
    },
  ),
  Candidat(
    id: 'cnd-03',
    nom: 'Divine T.',
    ville: 'Goma',
    photoUrl: '',
    videoUrl: '',
    streams: 295000,
    votes: 11300,
    notesJury: {
      CritereJury.voix: 9.5,
      CritereJury.presence: 9,
      CritereJury.originalite: 8.5,
      CritereJury.interpretation: 9.5,
    },
  ),
  Candidat(
    id: 'cnd-04',
    nom: 'Junior B.',
    ville: 'Matadi',
    photoUrl: '',
    videoUrl: '',
    streams: 87000,
    votes: 2400,
    notesJury: {
      CritereJury.voix: 7,
      CritereJury.presence: 8,
      CritereJury.originalite: 7.5,
      CritereJury.interpretation: 7,
    },
  ),
  Candidat(
    id: 'cnd-05',
    nom: 'Naomi L.',
    ville: 'Kinshasa',
    photoUrl: '',
    videoUrl: '',
    streams: 143000,
    votes: 5300,
    notesJury: {
      CritereJury.voix: 8.5,
      CritereJury.presence: 8,
      CritereJury.originalite: 9,
      CritereJury.interpretation: 8,
    },
  ),
];
