import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'folder_view.dart';
import 'package:intl/date_symbol_data_local.dart'; // Necesario para inicializar el idioma

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await initializeDateFormatting(
      'es_MX', null); // Inicializa datos de fecha en español
  Intl.defaultLocale = 'es_MX'; // Establece el idioma por defecto
  runApp(MyApp());
}

/// ✅ Solicita permisos necesarios para Android 10, 11, 12, 13, 14
Future<void> _requestPermissions() async {
  // Comprueba si ya tiene permisos
  if (await Permission.manageExternalStorage.isGranted) return;

  // Solicita múltiples permisos compatibles con Android 13 y 14
  Map<Permission, PermissionStatus> statuses = await [
    Permission.manageExternalStorage,
    Permission.photos,
    Permission.videos,
  ].request();

  // Si algún permiso fue denegado, abrir configuración del sistema
  if (statuses.values.any((status) => status.isDenied)) {
    await openAppSettings();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nebula Vault',
      theme: ThemeData.dark(),
      home: FolderViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
