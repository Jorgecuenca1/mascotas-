import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Verificar conexión real haciendo ping al servidor
      try {
        final url = Uri.parse(ApiConfig.root);
        final response = await http.get(url).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            return http.Response('Timeout', 408);
          },
        );
        return response.statusCode < 500;
      } catch (e) {
        print('Error verificando conexión al servidor: $e');
        return false;
      }
    } catch (e) {
      print('Error verificando conectividad: $e');
      return false;
    }
  }

  Stream<ConnectivityResult> get connectivityStream => _connectivity.onConnectivityChanged;

  Future<void> initConnectivityListener(Function(bool) onConnectivityChanged) async {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) async {
      bool hasConn = result != ConnectivityResult.none;
      if (hasConn) {
        // Verificar conexión real al servidor
        hasConn = await hasConnection();
      }
      onConnectivityChanged(hasConn);
    });
  }
}