import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/sesion_provider.dart';
import 'providers/novedad_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SesionProvider()),
        ChangeNotifierProvider(create: (context) => NovedadProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SportsHub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8FC), // Fondo claro azulado
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white, // Título blanco
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Color(0xFF445D77)), // Texto secundario
        ),
        iconTheme: const IconThemeData(color: Colors.blueGrey),
        useMaterial3: true,
      ),

      home: Consumer<SesionProvider>(
        builder: (context, sesion, _) {
          if (!sesion.sesionCargada) {
            return const SplashScreen(); // muestra mientras se carga la sesión
          }
          return const HomeScreen(); // redibuja cuando usuario o rol cambian
        },
      ),
    );
  }
}
