// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:typed_data';

Future<void> pedirPermisosCompletos() async {
  // Android 13 o superior
  if (await Permission.manageExternalStorage.isGranted) {
    print("✅ Permiso MANAGE_EXTERNAL_STORAGE ya otorgado.");
  } else {
    final status = await Permission.manageExternalStorage.request();
    print("🔐 Resultado del permiso: $status");

    if (!status.isGranted) {
      print("❌ El usuario no otorgó acceso total a archivos.");
    }
  }

  // También pedir acceso a imágenes
  await Permission.photos.request(); // Para iOS (se ignora en Android)
  await Permission.storage.request(); // En Android <13
}

Future<bool> borrarActual(BuildContext context, AssetEntity asset) async {
  try {
    final result = await PhotoManager.editor.deleteWithIds([asset.id]);
    if (result.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archivo eliminado correctamente')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el archivo')));
    }
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
  }
  return false;
}

void mostrarToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<Set<String>> agregarFavorito(
    BuildContext context, AssetEntity file) async {
  final prefs = await SharedPreferences.getInstance();
  final id = file.id;

  Set<String> favorites = (prefs.getStringList('favorites') ?? []).toSet();

  if (favorites.contains(id)) {
    favorites.remove(id);
    mostrarToast(context, "Eliminado de favoritos");
  } else {
    favorites.add(id);
    mostrarToast(context, "Agregado a favoritos");
  }

  await prefs.setStringList('favorites', favorites.toList());

  return favorites;
}

String formatoDeDuracion(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
  } else {
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
  }
}

Future<void> borrarSeleccionados(
    BuildContext context, Set<String> selectedIds) async {
  if (selectedIds.isEmpty) return;

  try {
    final result =
        await PhotoManager.editor.deleteWithIds(selectedIds.toList());

    if (result.isNotEmpty) {
      mostrarToast(context, "Se eliminaron ${result.length} elementos");
    } else {
      mostrarToast(context, "No se pudo eliminar ninguno");
    }
  } catch (e) {
    mostrarToast(context, "Error al eliminar: $e");
  }
}

Future<void> setFolderThumbnail({
  required BuildContext context,
  required String folderName,
  required AssetEntity asset,
}) async {
  // Mostrar el modal de confirmación con preview
  bool confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('¿Usar esta imagen como portada?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FutureBuilder<Uint8List?>(
                    future:
                        asset.thumbnailDataWithSize(ThumbnailSize(300, 200)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasData) {
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      } else {
                        return const Text("No se pudo cargar la imagen.");
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                    'Esta imagen se mostrará como portada de la carpeta.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ) ??
      false;

  // Si el usuario cancela, no guardar
  if (!confirm) return;

  // Obtener SharedPreferences y guardar la info
  final prefs = await SharedPreferences.getInstance();
  final String? rawData = prefs.getString('folder_thumbnails');
  List<dynamic> thumbnailList = rawData != null ? jsonDecode(rawData) : [];

  final index =
      thumbnailList.indexWhere((entry) => entry['carpeta'] == folderName);

  if (index != -1) {
    thumbnailList[index]['fotoId'] = asset.id;
  } else {
    thumbnailList.add({'carpeta': folderName, 'fotoId': asset.id});
  }

  await prefs.setString('folder_thumbnails', jsonEncode(thumbnailList));
}

Future<String?> getFolderThumbnailId(String folderName) async {
  final prefs = await SharedPreferences.getInstance();
  final String? rawData = prefs.getString('folder_thumbnails');

  if (rawData == null) return null;

  List<dynamic> thumbnailList = jsonDecode(rawData);
  final entry = thumbnailList.firstWhere(
    (e) => e['carpeta'] == folderName,
    orElse: () => null,
  );

  return entry != null ? entry['fotoId'] : null;
}
