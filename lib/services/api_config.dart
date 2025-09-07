class ApiConfig {
  // Raíz del backend, por ejemplo: http://localhost:8000/
  static const String root = String.fromEnvironment(
    'API_ROOT',
    defaultValue: 'http://127.0.0.1:8000/',  // URL del servidor local para pruebas
  );

  // Base API, por ejemplo: http://localhost:8000/api/
  static const String baseOverride = String.fromEnvironment('API_BASE', defaultValue: '');

  static String get apiBase {
    if (baseOverride.isNotEmpty) return _ensureEndsWithSlash(baseOverride);
    final r = _ensureEndsWithSlash(root);
    return '${r}api/';
  }

  static String _ensureEndsWithSlash(String url) {
    return url.endsWith('/') ? url : '$url/';
  }
}



