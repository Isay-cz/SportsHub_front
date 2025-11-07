import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sesion_provider.dart';
import '../providers/novedad_provider.dart';
import 'pages/inicio_page.dart';
import 'pages/perfil_page.dart';
import 'pages/favoritos_page.dart';
import 'pages/notificaciones_page.dart';
import 'pages/panel_admin_page.dart';
import 'pages/panel_director_page.dart';
import 'pages/panel_arbitro_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final GlobalKey<InicioPageState> _inicioKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Iniciar la conexión de novedades después de que el widget se construya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNovedadesConnection();
    });
  }

  void _initNovedadesConnection() {
    final sesion = Provider.of<SesionProvider>(context, listen: false);
    final novedadProvider = Provider.of<NovedadProvider>(context, listen: false);
    if (sesion.estaAutenticado) {
      novedadProvider.connect(sesion.id!);
    }
  }

  void _onTabTapped(int index) {
    // Si el usuario va a la pestaña de notificaciones, marcamos que las vio
    if (index == 2) {
      Provider.of<NovedadProvider>(context, listen: false).marcarNovedadesComoVistas();
    }

    if (_currentIndex == index && index == 0) {
      _inicioKey.currentState?.recargar();
    } else {
      setState(() => _currentIndex = index);
      _pageController.jumpToPage(index);
    }
  }

  void recargarInicio() {
    _inicioKey.currentState?.recargar();
  }

  void _showSimulatedPush(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Hay una nueva novedad!'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'VER',
          onPressed: () => _onTabTapped(2), // Navega a la pestaña de notificaciones
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Provider.of<SesionProvider>(context);

    // --- LÓGICA PARA LA NOTIFICACIÓN PUSH SIMULADA ---
    return Consumer<NovedadProvider>(
      builder: (context, novedadProvider, child) {
        // Si hay novedades y no estamos en la pestaña de notificaciones
        if (novedadProvider.hayNovedadesNoVistas && _currentIndex != 2) {
          // Usamos un callback para mostrar el SnackBar después de que se construya el widget
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSimulatedPush(context);
          });
        }

        // El resto del build sigue igual
        final rol = sesion.rol;
        List<Widget> pages = [
          InicioPage(key: _inicioKey),
          const FavoritosPage(),
          const NotificacionesPage(),
        ];

        List<BottomNavigationBarItem> items = [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite_sharp), label: ''),
          // --- BADGE DE NOTIFICACIÓN ---
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: novedadProvider.hayNovedadesNoVistas,
              child: const Icon(Icons.notifications),
            ),
            label: '',
          ),
        ];

        // ... (el resto de tu lógica de paneles y perfil no cambia)
        if (rol == 'admin') {
          pages.add(const PanelAdminPage());
          items.add(
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: ''),
          );
        } else if (rol == 'director') {
          pages.add(const PanelDirectorPage());
          items.add(const BottomNavigationBarItem(icon: Icon(Icons.group), label: ''));
        } else if (rol == 'arbitro') {
          pages.add(const PanelArbitroPage());
          items.add(const BottomNavigationBarItem(icon: Icon(Icons.sports), label: ''));
        }
        pages.add(PerfilPage(onLoginSuccess: recargarInicio));
        items.add(const BottomNavigationBarItem(icon: Icon(Icons.person), label: ''));

        if (_currentIndex >= pages.length) {
          _currentIndex = pages.length - 1;
        }

        if (_currentIndex == 3 &&
            (rol == 'admin' || rol == 'director' || rol == 'arbitro')) {
          _currentIndex = 3;
        }

        return Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            items: items,
          ),
        );
      },
    );
  }
}
