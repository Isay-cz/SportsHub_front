import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/novedad_provider.dart';
import '../../providers/sesion_provider.dart';
import 'partido_detalle_page.dart';

class NotificacionesPage extends StatelessWidget {
  const NotificacionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novedades'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body:
          sesion.estaAutenticado
              ? Consumer<NovedadProvider>(
                builder: (context, novedadProvider, child) {
                  if (!novedadProvider.isConnected && novedadProvider.novedades.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (novedadProvider.novedades.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_paused_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No hay novedades recientes.",
                            style: TextStyle(fontSize: 18, color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildNotificationList(novedadProvider.novedades);
                },
              )
              : _buildLoginPrompt(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Inicia sesión para ver las novedades',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> novedades) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: novedades.length,
      itemBuilder: (context, index) {
        final novedad = novedades[index];
        // Pasamos el contexto para poder navegar si es necesario
        return _buildNotificationCard(context, novedad);
      },
    );
  }

  // --- WIDGET DE TARJETA REDISEÑADO ---
  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> novedad) {
    final type = novedad['tipo'] ?? 'status';
    final data = novedad['data'];

    IconData icon;
    Color color;
    String title;
    String subtitle;

    print("///////////////////");
    print(novedad);

    switch (type) {
      case 'resultado_actualizado':
        icon = Icons.sports_soccer;
        color = Colors.green;
        title = "Resultado Actualizado";
        subtitle = data?['mensaje'] ?? 'El marcador de un partido ha cambiado.';
        break;
      case 'partido_agregado':
        icon = Icons.event_available;
        color = Colors.blue;
        title = "Nuevo Partido Programado";
        subtitle = data?['mensaje'] ?? 'Se ha añadido un nuevo partido a una liga.';
        break;
      default:
        icon = Icons.info_outline_rounded;
        color = Colors.grey.shade700;
        title = "Novedad del Sistema";
        subtitle = data?['mensaje'] ?? 'Ha ocurrido un evento.';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: InkWell(
        // Para dar efecto visual al tocar
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (data != null && data['partido_id'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PartidoDetallePage(partidoId: data['partido_id']),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Círculo del ícono
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              // Contenido de texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
