/// Version iOS : aucune régie publicitaire n'est embarquée.
///
/// Le SDK Unity LevelPlay n'est pas inclus dans le build iPhone (il n'est
/// utilisé que sur Android). Cette classe garde la même interface pour que le
/// reste de l'application fonctionne sans modification : la régie est toujours
/// « indisponible », donc l'application passe directement à la vidéo.
class ServiceLevelPlay {
  ServiceLevelPlay._();
  static final ServiceLevelPlay instance = ServiceLevelPlay._();

  bool get disponible => false;
  bool get prete => false;

  Future<void> initialiser({String? identifiantUtilisateur}) async {}

  void preparer() {}

  Future<bool> montrerAvecFin({required void Function(bool regardee) surFin}) async => false;
}
