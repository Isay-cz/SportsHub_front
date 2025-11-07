import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../clases.dart';

// Clase Evento (sin cambios)
class Evento {
  final String tipo;
  final String detalle;
  final Jugador? jugador;
  final String equipoId;
  final DateTime timestamp;

  Evento({
    required this.tipo,
    required this.detalle,
    this.jugador,
    required this.equipoId,
    required this.timestamp,
  });

  factory Evento.fromMap(Map<String, dynamic> map, List<Jugador> jugadores) {
    final parts = (map.values.first as List).cast<String>();
    final tipo = parts.isNotEmpty ? parts[0] : 'desconocido';
    final equipoId = parts.length > 1 ? parts[1] : '';
    final jugadorNombre = parts.length > 2 ? parts[2] : null;
    final detalle = parts.length > 3 ? parts[3] : '';

    return Evento(
      tipo: tipo,
      equipoId: equipoId,
      jugador:
          jugadorNombre != null && jugadorNombre.isNotEmpty
              ? jugadores.firstWhere(
                (j) => j.nombre == jugadorNombre,
                orElse:
                    () =>
                        Jugador(nombre: jugadorNombre, numero: 0, posicion: '', edad: 0),
              )
              : null,
      detalle: detalle,
      timestamp: DateTime.now(),
    );
  }

  List<String> toList() {
    return [tipo, equipoId, jugador?.nombre ?? '', detalle];
  }
}

class PartidoRegistroPage extends StatefulWidget {
  final String partidoId;
  const PartidoRegistroPage({Key? key, required this.partidoId}) : super(key: key);

  @override
  State<PartidoRegistroPage> createState() => _PartidoRegistroPageState();
}

class _PartidoRegistroPageState extends State<PartidoRegistroPage> {
  Partido? _partido;
  Equipo? _localEquipo;
  Equipo? _visitanteEquipo;
  Reglas? _reglas;
  bool _cargando = true;
  Timer? _debounce;

  final TextEditingController _notaCtrl = TextEditingController();
  List<Evento> _eventos = [];
  List<String> _notasArbitro = [];
  Map<String, int> _resultado = {};
  bool _cargandoFinalizar = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosCompletos();
  }

  Future<void> _cargarDatosCompletos() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://10.0.2.2:8000/partidos/${widget.partidoId}')),
        http.get(Uri.parse('http://10.0.2.2:8000/partidos/${widget.partidoId}/reglas')),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('No se pudo cargar la información inicial del partido.');
      }

      final p = Partido.fromJson(jsonDecode(responses[0].body));
      final r = Reglas.fromJson(jsonDecode(responses[1].body));

      final equiposRes = await Future.wait([
        http.get(Uri.parse('http://10.0.2.2:8000/equipos/${p.localId}')),
        http.get(Uri.parse('http://10.0.2.2:8000/equipos/${p.visitanteId}')),
      ]);

      if (equiposRes.any((res) => res.statusCode != 200))
        throw Exception('No se pudieron cargar los equipos.');

      final local = Equipo.fromJson(jsonDecode(equiposRes[0].body));
      final visitante = Equipo.fromJson(jsonDecode(equiposRes[1].body));

      setState(() {
        _partido = p;
        _reglas = r;
        _localEquipo = local;
        _visitanteEquipo = visitante;
        _resultado = p.resultado ?? {p.localId: 0, p.visitanteId: 0};
        _notasArbitro = p.notas;

        if (p.eventos != null) {
          final List<Jugador> todosLosJugadores = [
            ...(local.jugadores ?? []),
            ...(visitante.jugadores ?? []),
          ];
          _eventos =
              p.eventos!.entries
                  .map((e) => Evento.fromMap({e.key: e.value}, todosLosJugadores))
                  .toList();
        }

        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos de partido: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al cargar los detalles')));
        Navigator.pop(context);
      }
    }
  }

  void _recalcularYGuardar() {
    if (_partido == null || _reglas == null) return;

    int puntosLocal = 0;
    int puntosVisitante = 0;

    for (final evento in _eventos.where((e) => e.tipo == 'punto')) {
      final valor = _reglas!.anotaciones[evento.detalle] ?? 0;
      if (evento.equipoId == _partido!.localId) {
        puntosLocal += valor;
      } else {
        puntosVisitante += valor;
      }
    }

    setState(() {
      _resultado[_partido!.localId] = puntosLocal;
      _resultado[_partido!.visitanteId] = puntosVisitante;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _actualizarPartidoCompletoEnBackend();
    });
  }
  // ... (después de _eliminarNota)

  // --- FUNCIÓN PARA ENVIAR ESTADÍSTICAS (NUEVA) ---
  Future<bool> _enviarEstadisticas(
    String equipoId,
    int ganados,
    int perdidos,
    int empatados,
    int puntos,
  ) async {
    final url = Uri.parse('http://10.0.2.2:8000/equipos/actualizar_estadisticas');
    final payload = {
      "id_equipo": equipoId,
      "ganados": ganados,
      "perdidos": perdidos,
      "empatados": empatados,
      "puntos": puntos,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      // Asumimos que 200 (OK) es la respuesta correcta del backend
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error al enviar estadísticas para $equipoId: $e');
      return false;
    }
  }

  // --- FUNCIÓN PRINCIPAL PARA FINALIZAR EL PARTIDO (NUEVA) ---
  Future<void> _finalizarPartido() async {
    if (_partido == null) return;

    // 1. Confirmar
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('¿Finalizar partido?'),
            content: const Text(
              'Esta acción actualizará las estadísticas de los equipos con el resultado actual. ¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finalizar'),
              ),
            ],
          ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _cargandoFinalizar = true);

    // 2. Calcular resultados y puntos
    final localId = _partido!.localId;
    final visitanteId = _partido!.visitanteId;
    final localScore = _resultado[localId] ?? 0;
    final visitanteScore = _resultado[visitanteId] ?? 0;

    // Asumimos: 3 puntos por victoria, 1 por empate, 0 por derrota
    int gL = 0, pL = 0, eL = 0, ptsL = 0;
    int gV = 0, pV = 0, eV = 0, ptsV = 0;

    if (localScore > visitanteScore) {
      gL = 1;
      ptsL = 3;
      pV = 1;
      ptsV = 0; // Puntos por derrota
    } else if (visitanteScore > localScore) {
      pL = 1;
      ptsL = 0; // Puntos por derrota
      gV = 1;
      ptsV = 3;
    } else {
      // Empate
      eL = 1;
      ptsL = 1;
      eV = 1;
      ptsV = 1;
    }

    // 3. Enviar actualizaciones al backend (una por equipo)
    bool okLocal = await _enviarEstadisticas(localId, gL, pL, eL, ptsL);
    bool okVisitante = await _enviarEstadisticas(visitanteId, gV, pV, eV, ptsV);

    if (!mounted) return;
    setState(() => _cargandoFinalizar = false);

    // 4. Mostrar resultado
    if (okLocal && okVisitante) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partido finalizado. Estadísticas actualizadas.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Volver al panel de árbitro
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar estadísticas. Intenta de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ... (resto del archivo)

  Future<void> _actualizarPartidoCompletoEnBackend() async {
    if (_partido == null) return;

    final eventosParaBackend = {
      for (int i = 0; i < _eventos.length; i++) i.toString(): _eventos[i].toList(),
    };

    final body = {
      '_id': _partido!.id,
      'arbitro_id': _partido!.arbitroId,
      'local_id': _partido!.localId,
      'visitante_id': _partido!.visitanteId,
      'lugar': _partido!.lugar,
      'horario': {
        'hora_inicio': _partido!.horario.horaInicio.toIso8601String(),
        'hora_fin': _partido!.horario.horaFin.toIso8601String(),
      },
      'resultado': _resultado,
      'notas': _notasArbitro,
      'eventos': eventosParaBackend,
    };

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:8000/partidos/${_partido!.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200 && mounted) {
        throw Exception('Error al guardar: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error al actualizar el partido: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al guardar los cambios')));
      }
    }
  }

  void _registrarEvento(String tipo, Equipo equipo) {
    if (_reglas == null || equipo.jugadores == null || equipo.jugadores!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El equipo ${equipo.nombre} no tiene jugadores registrados.'),
        ),
      );
      return;
    }

    final detalles =
        tipo == 'punto'
            ? _reglas!.anotaciones.keys.toList()
            : _reglas!.faltas.keys.toList();
    Jugador? jugadorSeleccionado;
    String? detalleSeleccionado;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Registrar $tipo para ${equipo.nombre}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Jugador>(
                  decoration: const InputDecoration(labelText: 'Jugador'),
                  items:
                      equipo.jugadores!
                          .map((j) => DropdownMenuItem(value: j, child: Text(j.nombre)))
                          .toList(),
                  onChanged: (v) => jugadorSeleccionado = v,
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: tipo == 'punto' ? 'Tipo de punto' : 'Tipo de falta',
                  ),
                  items:
                      detalles
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                  onChanged: (v) => detalleSeleccionado = v,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (jugadorSeleccionado != null && detalleSeleccionado != null) {
                    setState(() {
                      _eventos.add(
                        Evento(
                          tipo: tipo,
                          detalle: detalleSeleccionado!,
                          jugador: jugadorSeleccionado,
                          equipoId: equipo.id,
                          timestamp: DateTime.now(),
                        ),
                      );
                    });
                    Navigator.pop(context);
                    _recalcularYGuardar();
                  }
                },
                child: const Text('Registrar'),
              ),
            ],
          ),
    );
  }

  void _agregarNota() {
    final textoNota = _notaCtrl.text.trim();
    if (textoNota.isNotEmpty) {
      setState(() {
        _notasArbitro.add(textoNota);
        _notaCtrl.clear();
      });
      _recalcularYGuardar();
    }
  }

  void _eliminarNota(String nota) {
    setState(() {
      _notasArbitro.remove(nota);
    });
    _recalcularYGuardar();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l = _localEquipo!;
    final v = _visitanteEquipo!;
    final fechaFmt = DateFormat(
      'EEE, dd MMMM yyyy - HH:mm',
      'es_ES',
    ).format(_partido!.horario.horaInicio);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registro de Partido'),
          bottom: const TabBar(tabs: [Tab(text: 'EN VIVO'), Tab(text: 'NOTAS')]),
          actions: [
            if (_cargandoFinalizar)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24, // Tamaño consistente
                  height: 24, // Tamaño consistente
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Finalizar Partido',
                onPressed: _finalizarPartido,
              ),
          ],
        ),
        body: TabBarView(children: [_buildLiveTab(l, v, fechaFmt), _buildNotasTab()]),
      ),
    );
  }

  Widget _buildLiveTab(Equipo local, Equipo visitante, String fecha) {
    return Column(
      children: [
        _buildHeader(local, visitante, fecha),
        _buildAcciones(local, visitante),
        const Divider(height: 1),
        _buildCronologiaEventos(),
      ],
    );
  }

  Widget _buildHeader(Equipo local, Equipo visitante, String fecha) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(fecha, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                local.nombre,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                "${_resultado[local.id] ?? 0} - ${_resultado[visitante.id] ?? 0}",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Text(
                visitante.nombre,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones(Equipo local, Equipo visitante) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.sports_basketball),
                label: const Text('Punto'),
                onPressed: () => _registrarEvento('punto', local),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.warning_amber),
                label: const Text('Falta'),
                onPressed: () => _registrarEvento('falta', local),
              ),
            ],
          ),
          Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.sports_basketball),
                label: const Text('Punto'),
                onPressed: () => _registrarEvento('punto', visitante),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.warning_amber),
                label: const Text('Falta'),
                onPressed: () => _registrarEvento('falta', visitante),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCronologiaEventos() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _eventos.length,
        reverse: true,
        itemBuilder: (context, index) {
          final evento = _eventos.reversed.toList()[index];
          final esLocal = evento.equipoId == _localEquipo!.id;
          final nombreEquipo = esLocal ? _localEquipo!.nombre : _visitanteEquipo!.nombre;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Icon(
                evento.tipo == 'punto' ? Icons.sports_basketball : Icons.warning_amber,
                color: esLocal ? Colors.blue : Colors.red,
              ),
              title: Text("${evento.jugador?.nombre ?? 'Sistema'} ($nombreEquipo)"),
              subtitle: Text(evento.detalle),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () {
                  setState(() => _eventos.remove(evento));
                  _recalcularYGuardar();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotasTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Notas del Árbitro",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _notaCtrl,
                decoration: const InputDecoration(labelText: 'Añadir nueva nota...'),
              ),
            ),
            IconButton(icon: const Icon(Icons.add_comment), onPressed: _agregarNota),
          ],
        ),
        const SizedBox(height: 8),
        ..._notasArbitro.map(
          (nota) => Card(
            child: ListTile(
              title: Text(nota),
              leading: const Icon(Icons.speaker_notes, color: Colors.blue),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _eliminarNota(nota),
              ),
            ),
          ),
        ),

        const Divider(height: 40),

        const Text(
          "Notas de Reglas",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_reglas?.notas == null || _reglas!.notas!.isEmpty)
          const Center(child: Text('No hay notas de reglas para este deporte.'))
        else
          ..._reglas!.notas!.map(
            (nota) => Card(
              color: Colors.grey[200],
              child: ListTile(leading: const Icon(Icons.rule), title: Text(nota)),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
