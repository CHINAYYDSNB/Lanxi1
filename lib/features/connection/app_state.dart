import 'package:flutter/foundation.dart';
import 'package:lanxi/services/server_service.dart';

/// Holds the current [ServerService] connection state.
///
/// Passed down the widget tree. Pages read [service] to call server operations.
class AppState extends ChangeNotifier {
  ServerService? _service;

  ServerService? get service => _service;

  bool get isConnected => _service != null;

  void connect(ServerService service) {
    _service = service;
    notifyListeners();
  }

  void disconnect() {
    _service = null;
    notifyListeners();
  }
}
