// lib/screens/pages/liga_detalle_admin_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// --- AÑADIR IMPORTS PARA PDF ---
import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../../services/reporte_service.dart';
// --- FIN DE IMPORTS ---

import '../../clases.dart';
import 'create_account_page.dart';
import 'create_match_page.dart';

class LigaDetalleAdminPage extends StatefulWidget {
  final Liga liga;
  const LigaDetalleAdminPage({super.key, required this.liga});

  @override
  State<LigaDetalleAdminPage> createState() => _LigaDetalleAdminPageState();
}

class _LigaDetalleAdminPageState extends State<LigaDetalleAdminPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Partido> partidos = [];
  List<Equipo> equipos = [];
  List<Director> directores = [];
  List<Arbitro> arbitros = [];
  bool cargando = true;
  late Liga _liga;

  bool _cargandoReporte = false; // <-- AÑADIR ESTADO DE CARGA

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refrescarLigaYDatos();
  }

  // ... (Las funciones _refrescarLigaYDatos y cargarDatos no cambian) ...
  Future<void> _refrescarLigaYDatos() async {
    // ... (código existente) ...
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/ligas/${widget.liga.id}'),
    );
    print('Código de estado: ${response.statusCode}');
    print('Respuesta completa: ${response.body}');
    if (response.statusCode == 200) {
      _liga = Liga.fromJson(jsonDecode(response.body));
      cargarDatos();
    }
  }

  Future<void> cargarDatos() async {
    // ... (código existente) ...
    try {
      final liga = _liga;
      final List<Equipo> eqs = [];
      final List<Partido> pts = [];
      final List<Director> dirs = [];
      final List<Arbitro> arbs = [];

      print("------asdfdsf-------------------");
      for (var id in liga.equipos) {
        final r = await http.get(Uri.parse('http://10.0.2.2:8000/equipos/$id'));
        if (r.statusCode == 200) eqs.add(Equipo.fromJson(jsonDecode(r.body)));
        print('Código de estado: ${r.statusCode}');
        print('Respuesta completa: ${r.body}');
      }

      for (var id in liga.partidos) {
        final r = await http.get(Uri.parse('http://10.0.2.2:8000/partidos/$id'));
        if (r.statusCode == 200) pts.add(Partido.fromJson(jsonDecode(r.body)));
        print('Código de estado: ${r.statusCode}');
        print('Respuesta completa: ${r.body}');
      }
      for (var id in liga.directores) {
        final r = await http.get(Uri.parse('http://10.0.2.2:8000/director/$id'));
        print('Código de estado: ${r.statusCode}');
        print('Respuesta completa: ${r.body}');
        if (r.statusCode == 200) dirs.add(Director.fromJson(jsonDecode(r.body)));
        print(dirs);
      }
      print("-------------asdfdsf------------");
      for (var id in liga.arbitros) {
        final r = await http.get(Uri.parse('http://10.0.2.2:8000/arbitro/$id'));
        if (r.statusCode == 200) arbs.add(Arbitro.fromJson(jsonDecode(r.body)));
        print('Código de estado: ${r.statusCode}');
        print('Respuesta completa: ${r.body}');
        print(arbs);
      }

      setState(() {
        equipos = eqs..sort((a, b) => (a.posicion ?? 999).compareTo(b.posicion ?? 999));
        partidos = pts;
        directores = dirs;
        arbitros = arbs;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  // --- AÑADIR NUEVA FUNCIÓN PARA GENERAR REPORTE ---
  Future<void> _generarReporteLiga() async {
    // No generar si los datos principales aún están cargando
    if (cargando) return;

    setState(() => _cargandoReporte = true);

    // Mostrar un diálogo de carga simple
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generar el PDF usando el servicio y los datos del estado
      final Uint8List pdfBytes = await ReporteService.generarReporteLigaAdmin(
        _liga,
        equipos,
        partidos,
        arbitros,
        directores,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar el diálogo de carga

      // Mostrar el diálogo para compartir/guardar el PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'reporte_liga_${_liga.nombre.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Error al generar reporte de liga: $e');
      if (mounted) {
        Navigator.pop(context); // Cerrar el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar el reporte PDF')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoReporte = false);
      }
    }
  }

  // ... (Todas las demás funciones: _buildPartidosTab, eliminarEquipo, _buildEquiposTab, _eliminarCuenta, _buildCuentasTab, _mostrarPopupCrearEquipo, etc., se mantienen EXACTAMENTE IGUAL) ...
  Widget _buildPartidosTab() {
    final Map<String, String> idToNombreEquipo = {for (var e in equipos) e.id: e.nombre};

    final futuros =
        partidos.where((p) => (p.resultado == null || p.resultado!.isEmpty)).toList();

    final pasados =
        partidos.where((p) => (p.resultado != null && p.resultado!.isNotEmpty)).toList();

    String formatearHora(DateTime dt) => DateFormat('HH:mm').format(dt);

    Future<void> _eliminarPartido(String id) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Confirmar eliminación'),
              content: const Text(
                '¿Deseas eliminar este partido? Esta acción no se puede deshacer.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
      );

      if (confirm != true) return;

      try {
        final res = await http.delete(Uri.parse('http://10.0.2.2:8000/partidos/$id'));

        if (res.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Partido eliminado')));
          _refrescarLigaYDatos(); // recarga los datos
        } else {
          debugPrint('Error: ${res.body}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No se pudo eliminar el partido')));
        }
      } catch (e) {
        debugPrint('Error de conexión: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error de red al eliminar partido')));
      }
    }

    Widget _partidoTile(Partido p, {bool esPasado = false}) {
      return ListTile(
        title: Text(
          '${idToNombreEquipo[p.localId] ?? p.localId} vs ${idToNombreEquipo[p.visitanteId] ?? p.visitanteId}',
        ),
        subtitle: Text(formatearHora(p.horario.horaInicio)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (esPasado)
              Text(
                '${p.resultado?[p.localId] ?? 0} - ${p.resultado?[p.visitanteId] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            else
              const Text('-'),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _eliminarPartido(p.id),
              tooltip: 'Eliminar partido',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refrescarLigaYDatos(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => CreateMatchPage(
                          ligaId: widget.liga.id,
                          ligaReglasId: widget.liga.reglasId,
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear partido'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Futuros',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...futuros.map((p) => _partidoTile(p)),
          const SizedBox(height: 20),
          const Text(
            'Finalizados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...pasados.map((p) => _partidoTile(p, esPasado: true)),
        ],
      ),
    );
  }

  Future<void> eliminarEquipo(String idEquipo) async {
    final ligaId = widget.liga.id;

    try {
      // Eliminar el equipo de la liga
      final r1 = await http.post(
        Uri.parse('http://10.0.2.2:8000/ligas/eliminar_equipo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_liga': ligaId, 'id_item': idEquipo}),
      );

      // Eliminar el equipo completamente
      final r2 = await http.delete(Uri.parse('http://10.0.2.2:8000/equipos/$idEquipo'));

      if (r1.statusCode == 200 && r2.statusCode == 200) {
        setState(() => equipos.removeWhere((e) => e.id == idEquipo));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo eliminar el equipo')));
        debugPrint('Error al eliminar equipo: ${r1.body} - ${r2.body}');
      }
    } catch (e) {
      debugPrint('Excepción al eliminar equipo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión al eliminar equipo')),
      );
    }
  }

  Widget _buildEquiposTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: equipos.length,
            itemBuilder: (_, i) {
              final e = equipos[i];
              return ListTile(
                title: Text(e.nombre),
                subtitle: Text(
                  'G: ${e.partidosGanados}, E: ${e.partidosEmpatados}, P: ${e.partidosPerdidos}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${e.puntosLiga} pts'),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Confirmar eliminación'),
                                content: Text('¿Eliminar el equipo "${e.nombre}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                        );

                        if (confirmar == true) {
                          await eliminarEquipo(e.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _mostrarPopupCrearEquipo,
            icon: const Icon(Icons.add),
            label: const Text('Agregar equipo'),
          ),
        ),
      ],
    );
  }

  Future<void> _eliminarCuenta(String tipo, String idUsuario, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que deseas eliminar a $nombre del rol de $tipo? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final ligaId = widget.liga.id;
    final urlEliminarDeLiga = 'http://10.0.2.2:8000/ligas/eliminar_${tipo.toLowerCase()}';
    final urlEliminarUsuario = 'http://10.0.2.2:8000/$tipo/$idUsuario';

    try {
      // Paso 1: Eliminar del registro de liga
      final ligaResp = await http.post(
        Uri.parse(urlEliminarDeLiga),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_liga': ligaId, 'id_item': idUsuario}),
      );

      if (ligaResp.statusCode != 200) {
        throw Exception('No se pudo eliminar de la liga');
      }

      // Paso 2: Eliminar al usuario completamente
      final userResp = await http.delete(Uri.parse(urlEliminarUsuario));

      if (userResp.statusCode != 200) {
        throw Exception('No se pudo eliminar el usuario');
      }

      setState(() {
        if (tipo == 'director') {
          directores.removeWhere((d) => d.id == idUsuario);
        } else {
          arbitros.removeWhere((a) => a.id == idUsuario);
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cuenta eliminada correctamente')));
    } catch (e) {
      debugPrint('Error al eliminar cuenta: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al eliminar la cuenta')));
    }
  }

  Widget _buildCuentasTab() {
    return RefreshIndicator(
      onRefresh: () => _refrescarLigaYDatos(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Directores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...directores.map(
            (d) => ListTile(
              title: Text(d.nombre),
              subtitle: Text(d.correo),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _eliminarCuenta('director', d.id, d.nombre),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Árbitros',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...arbitros.map(
            (a) => ListTile(
              title: Text(a.nombre),
              subtitle: Text(a.correo),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _eliminarCuenta('arbitro', a.id, a.nombre),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAccountPage(ligaId: widget.liga.id),
                  ),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar cuenta'),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarPopupCrearEquipo() async {
    final nombreCtrl = TextEditingController();
    String? directorId;
    List<Usuario> directoresDisponibles = [];

    try {
      final res = await http.get(
        Uri.parse('http://10.0.2.2:8000/ligas/${widget.liga.id}/directores_sin_equipo'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List ids = data['directores_sin_equipo'] as List;

        for (final id in ids) {
          final r = await http.get(Uri.parse('http://10.0.2.2:8000/director/$id'));
          if (r.statusCode == 200) {
            final obj = jsonDecode(r.body);
            directoresDisponibles.add(Director.fromJson(obj));
          }
        }
      } else {
        throw Exception('Fallo al obtener directores');
      }
    } catch (e) {
      debugPrint('Error al cargar directores: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener directores disponibles')),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Registrar nuevo equipo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del equipo'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: directorId,
                  decoration: const InputDecoration(labelText: 'Director'),
                  items:
                      directoresDisponibles
                          .map(
                            (d) => DropdownMenuItem(value: d.id, child: Text(d.nombre)),
                          )
                          .toList(),
                  onChanged: (val) => directorId = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreCtrl.text.trim().isEmpty || directorId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completa todos los campos.')),
                    );
                    return;
                  }

                  final nuevaPosicion =
                      equipos.isEmpty
                          ? 1
                          : (equipos
                                  .map((e) => e.posicion ?? 0)
                                  .reduce((a, b) => a > b ? a : b) +
                              1);

                  final equipoData = {
                    "nombre": nombreCtrl.text.trim(),
                    "director_id": directorId,
                    "puntos_liga": 0,
                    "partidos_ganados": 0,
                    "partidos_empatados": 0,
                    "partidos_perdidos": 0,
                    "jugadores": [],
                    "posicion": nuevaPosicion,
                  };

                  final payload = {"id_liga": widget.liga.id, "equipo": equipoData};

                  try {
                    final response = await http.post(
                      Uri.parse("http://10.0.2.2:8000/equipos/registrar_en_liga"),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode(payload),
                    );

                    if (response.statusCode == 200) {
                      final body = jsonDecode(response.body);
                      final nuevoEquipo = Equipo.fromJson({
                        "_id": body["id_equipo"],
                        "nombre": nombreCtrl.text.trim(),
                        "director_id": directorId,
                        "jugadores": [],
                        "puntos_liga": 0,
                        "partidos_ganados": 0,
                        "partidos_empatados": 0,
                        "partidos_perdidos": 0,
                        "posicion": nuevaPosicion,
                      });

                      setState(() => equipos.add(nuevoEquipo));
                      Navigator.pop(context);
                    } else {
                      debugPrint('Error al crear equipo: ${response.body}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al crear el equipo.')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Excepción: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error de conexión al crear equipo.')),
                    );
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.liga.nombre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Partidos'), Tab(text: 'Equipos'), Tab(text: 'Cuentas')],
          unselectedLabelColor: Colors.white,
          labelColor: const Color.fromARGB(255, 151, 181, 233),
        ),
        // --- INICIO DE MODIFICACIÓN ---
        actions: [
          if (_cargandoReporte)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Generar Reporte de Liga',
              onPressed: _generarReporteLiga,
            ),
        ],
        // --- FIN DE MODIFICACIÓN ---
      ),
      body:
          cargando
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [_buildPartidosTab(), _buildEquiposTab(), _buildCuentasTab()],
              ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
