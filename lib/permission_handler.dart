import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermissions() async {
  if (await Permission.manageExternalStorage.isGranted) return;

  Map<Permission, PermissionStatus> statuses = await [
    Permission.manageExternalStorage,
    Permission.photos,
    Permission.videos,
  ].request();

  if (statuses.values.any((status) => status.isDenied)) {
    await openAppSettings(); // Redirige al usuario a otorgar permisos manualmente
  }
}
