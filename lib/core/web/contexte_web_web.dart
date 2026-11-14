import 'dart:js_interop';

@JS('window.matchMedia')
external _Media? _matchMedia(JSString requete);

@JS('navigator.standalone')
external JSBoolean? get _standaloneIos;

extension type _Media(JSObject _) implements JSObject {
  external JSBoolean get matches;
}

/// Vrai si le site a été ajouté à l'écran d'accueil et s'ouvre comme une
/// application : Android/Chrome (display-mode) ou Safari iOS (standalone).
bool webInstalle() {
  try {
    for (final mode in const ['standalone', 'fullscreen', 'minimal-ui']) {
      final m = _matchMedia('(display-mode: $mode)'.toJS);
      if (m != null && m.matches.toDart) return true;
    }
  } catch (_) {}
  try {
    return _standaloneIos?.toDart ?? false;
  } catch (_) {
    return false;
  }
}
