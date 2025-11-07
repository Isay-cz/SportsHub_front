// lib/services/reporte_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../clases.dart';

class ReporteService {
  // --- FIRMA DE FUNCIÓN ACTUALIZADA ---
  static Future<Uint8List> generarReporteEquipo(
    Equipo equipo,
    List<Partido> partidosJugados,
    List<Partido> partidosFuturos, // <-- AÑADIDO
    Map<String, String> nombresEquipos,
  ) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              _buildHeader(equipo),
              pw.Divider(height: 20),
              _buildStats(equipo),
              pw.Divider(height: 20),
              _buildJugadores(equipo.jugadores ?? []),
              pw.Divider(height: 20),
              // --- NUEVA SECCIÓN AÑADIDA ---
              _buildPartidosFuturos(partidosFuturos, nombresEquipos, formatter),
              pw.Divider(height: 20),
              // --- FIN DE SECCIÓN AÑADIDA ---
              _buildPartidos(partidosJugados, equipo.id, nombresEquipos, formatter),
            ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generarReporteLigaAdmin(
    Liga liga,
    List<Equipo> equipos,
    List<Partido> partidos,
    List<Arbitro> arbitros,
    List<Director> directores,
  ) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    final DateFormat formatterHora = DateFormat('dd/MM HH:mm');

    // Mapa de nombres de equipos para los partidos
    final mapaNombres = {for (var e in equipos) e.id: e.nombre};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              _buildHeaderLiga(liga, formatter),
              pw.Divider(height: 20),
              _buildTablaPosiciones(equipos),
              pw.Divider(height: 20),
              _buildCalendarioPartidos(partidos, mapaNombres, formatterHora),
              pw.Divider(height: 20),
              _buildListasCuentas(arbitros, directores),
            ],
      ),
    );

    return pdf.save();
  }

  // --- Widgets Auxiliares para el nuevo reporte ---

  static pw.Widget _buildHeaderLiga(Liga liga, DateFormat formatter) {
    String fechaInicio = 'N/A';
    String fechaFin = 'N/A';

    if (liga.temporada.isNotEmpty) {
      fechaInicio = formatter.format(liga.temporada.first.horaInicio);
      fechaFin = formatter.format(liga.temporada.first.horaFin);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reporte General de Liga: ${liga.nombre}',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Fechas de temporada: $fechaInicio - $fechaFin'),
        pw.Text('Equipos inscritos: ${liga.equipos.length}'),
        pw.Text('Partidos programados: ${liga.partidos.length}'),
      ],
    );
  }

  static pw.Widget _buildTablaPosiciones(List<Equipo> equipos) {
    final headers = ['#', 'Equipo', 'PTS', 'G', 'E', 'P'];

    // El 'posicion' puede ser nulo, aseguramos un orden
    equipos.sort((a, b) => (a.posicion ?? 999).compareTo(b.posicion ?? 999));

    final data =
        equipos
            .map(
              (e) => [
                e.posicion?.toString() ?? '-',
                e.nombre,
                e.puntosLiga.toString(),
                e.partidosGanados.toString(),
                e.partidosEmpatados.toString(),
                e.partidosPerdidos.toString(),
              ],
            )
            .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tabla de Posiciones',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignments: {
            0: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
          },
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  static pw.Widget _buildCalendarioPartidos(
    List<Partido> partidos,
    Map<String, String> mapaNombres,
    DateFormat formatter,
  ) {
    final jugados =
        partidos.where((p) => p.resultado != null && p.resultado!.isNotEmpty).toList();
    final futuros =
        partidos.where((p) => p.resultado == null || p.resultado!.isEmpty).toList();

    String getNombre(String id) => mapaNombres[id] ?? 'ID: $id';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Calendario de Partidos',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),

        // --- Partidos Futuros ---
        if (futuros.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Partidos Futuros (${futuros.length})',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 5),
          ...futuros.map(
            (p) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  formatter.format(p.horario.horaInicio),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Expanded(
                  child: pw.Text(
                    '${getNombre(p.localId)} vs ${getNombre(p.visitanteId)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  'Pendiente',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            ),
          ),
        ],

        // --- Partidos Jugados ---
        if (jugados.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'Resultados (${jugados.length})',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
          pw.SizedBox(height: 5),
          ...jugados.map(
            (p) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  formatter.format(p.horario.horaInicio),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Expanded(
                  child: pw.Text(
                    '${getNombre(p.localId)} vs ${getNombre(p.visitanteId)}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(
                  '${p.resultado?[p.localId] ?? 0} - ${p.resultado?[p.visitanteId] ?? 0}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildListasCuentas(
    List<Arbitro> arbitros,
    List<Director> directores,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Personal de la Liga',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Árbitros (${arbitros.length})',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  ...arbitros.map(
                    (a) => pw.Text(a.nombre, style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Directores (${directores.length})',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  ...directores.map(
                    (d) => pw.Text(d.nombre, style: const pw.TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Widgets Auxiliares para el PDF ---

  static pw.Widget _buildHeader(Equipo equipo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reporte de Equipo: ${equipo.nombre}',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const pw.TextStyle(color: PdfColors.grey),
        ),
      ],
    );
  }

  static pw.Widget _buildStats(Equipo equipo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Estadísticas de la Liga',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _statBox('Puntos', equipo.puntosLiga.toString(), PdfColors.blue),
            _statBox('Ganados', equipo.partidosGanados.toString(), PdfColors.green),
            _statBox('Empatados', equipo.partidosEmpatados.toString(), PdfColors.orange),
            _statBox('Perdidos', equipo.partidosPerdidos.toString(), PdfColors.red),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static pw.Widget _buildJugadores(List<Jugador> jugadores) {
    final headers = ['#', 'Nombre', 'Posición', 'Edad'];
    final data =
        jugadores
            .map((j) => [j.numero.toString(), j.nombre, j.posicion, j.edad.toString()])
            .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Plantilla de Jugadores (${jugadores.length})',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  // --- NUEVA FUNCIÓN PARA PARTIDOS FUTUROS ---
  static pw.Widget _buildPartidosFuturos(
    List<Partido> partidos,
    Map<String, String> nombresEquipos,
    DateFormat formatter,
  ) {
    // Si no hay partidos futuros, no pintamos nada
    if (partidos.isEmpty) {
      return pw.Container();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Partidos Futuros (${partidos.length})',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        ...partidos.map((p) {
          final nombreLocal = nombresEquipos[p.localId] ?? 'Equipo';
          final nombreVisitante = nombresEquipos[p.visitanteId] ?? 'Equipo';

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 5),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(formatter.format(p.horario.horaInicio)),
                pw.Expanded(
                  child: pw.Text(
                    '$nombreLocal vs $nombreVisitante',
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Text(
                    'Pendiente',
                    style: const pw.TextStyle(color: PdfColors.grey),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  // --- FIN DE NUEVA FUNCIÓN ---

  // (Función _buildPartidos sin cambios, solo cambia el título)
  static pw.Widget _buildPartidos(
    List<Partido> partidos,
    String equipoId,
    Map<String, String> nombresEquipos,
    DateFormat formatter,
  ) {
    // Si no hay partidos jugados, no pintamos nada
    if (partidos.isEmpty) {
      return pw.Container();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Partidos Jugados (${partidos.length})', // Título ya es correcto
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        ...partidos.map((p) {
          final localId = p.localId;
          final visitanteId = p.visitanteId;

          final nombreLocal = nombresEquipos[localId] ?? 'Equipo';
          final nombreVisitante = nombresEquipos[visitanteId] ?? 'Equipo';

          final resultadoLocal = p.resultado?[localId] ?? 0;
          final resultadoVisitante = p.resultado?[visitanteId] ?? 0;

          final esVictoria =
              (localId == equipoId && resultadoLocal > resultadoVisitante) ||
              (visitanteId == equipoId && resultadoVisitante > resultadoLocal);
          final esDerrota =
              (localId == equipoId && resultadoLocal < resultadoVisitante) ||
              (visitanteId == equipoId && resultadoVisitante < resultadoLocal);

          final color =
              esVictoria
                  ? PdfColors.green
                  : (esDerrota ? PdfColors.red : PdfColors.orange);

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 5),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(formatter.format(p.horario.horaInicio)),
                pw.Expanded(
                  child: pw.Text(
                    '$nombreLocal vs $nombreVisitante',
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.Container(
                  color: color,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: pw.Text(
                    '$resultadoLocal - $resultadoVisitante',
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
