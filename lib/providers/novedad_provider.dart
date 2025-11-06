import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/notification_service.dart'; // Asegúrate que la ruta es correcta

class NovedadProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  StreamSubscription? _subscription;

  final List<Map<String, dynamic>> _novedades = [];
  bool _hayNovedadesNoVistas = false;

  List<Map<String, dynamic>> get novedades => _novedades;
  bool get hayNovedadesNoVistas => _hayNovedadesNoVistas;
  bool get isConnected => _service.isConnected;

  void connect(String userId) {
    if (_service.isConnected) return;

    _service.connect(userId);
    _subscription = _service.notificationStream.listen(_onNewNovedad);
  }

  void _onNewNovedad(String message) {
    print("NOVEDAD RECIBIDA (RAW): $message");

    // El stream puede enviar múltiples eventos en un solo chunk.
    // Los separamos por líneas para procesarlos individualmente.
    final lines = message.split('\n');

    for (final line in lines) {
      // Solo procesamos las líneas que contienen datos de un evento.
      if (line.startsWith('data: ')) {
        // Extraemos el contenido JSON, eliminando el prefijo 'data: '.
        final jsonData = line.substring(6).trim();

        // Si la línea de datos está vacía, la ignoramos.
        if (jsonData.isEmpty) continue;

        try {
          final data = json.decode(jsonData);

          // Normalizamos el ID para consistencia en la app.
          if (data.containsKey('_id') && data['_id'] != null) {
            data['id'] = data['_id'];
          }

          _novedades.insert(0, data);
          _hayNovedadesNoVistas = true;
          // Notificamos a la UI que hay nuevos datos.
          notifyListeners();
        } catch (e) {
          print("ERROR DECODIFICANDO JSON: $e");
          print("JSON problemático: $jsonData");
        }
      }
    }
  }

  void marcarNovedadesComoVistas() {
    if (_hayNovedadesNoVistas) {
      _hayNovedadesNoVistas = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _service.disconnect();
    _novedades.clear();
    _hayNovedadesNoVistas = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
