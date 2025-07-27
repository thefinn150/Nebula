// ignore_for_file: use_build_context_synchronously, avoid_print, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:photo_manager/photo_manager.dart';

Future<void> moverSeleccionados(BuildContext context, Set<String> selectedIds,
    List<AssetEntity> files) async {
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.isAuth) {
    mostrarToast(context, "No tienes permisos suficientes");
    return;
  }

  List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
    type: RequestType.image | RequestType.video,
    hasAll: false,
  );

  AssetPathEntity? selectedAlbum = await showDialog<AssetPathEntity>(
    context: context,
    builder: (ctx) {
      String filter = '';
      return StatefulBuilder(
        builder: (ctx, setState) {
          final filtered = albums
              .where((a) => a.name.toLowerCase().contains(filter.toLowerCase()))
              .toList();
          return AlertDialog(
            title: const Text("Selecciona carpeta destino"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Filtrar carpeta",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => filter = v),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final album = filtered[i];
                        return ListTile(
                          title: Text(album.name),
                          onTap: () => Navigator.pop(ctx, album),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar"),
              )
            ],
          );
        },
      );
    },
  );

  if (selectedAlbum == null) return;

  print(
      "Álbum destino seleccionado: ${selectedAlbum.name}, id: ${selectedAlbum.id}");

  final fileMap = {for (var f in files) f.id: f};

  selectedIds = selectedIds.where((id) => fileMap.containsKey(id)).toSet();
  if (selectedIds.isEmpty) {
    mostrarToast(context, "No hay archivos válidos para mover");
    return;
  }

  int movedCount = 0;

  for (final id in selectedIds) {
    final asset = fileMap[id];
    if (asset == null) {
      print("❌ Asset no encontrado para id $id");
      continue;
    }

    try {
      print("➡️ Intentando copiar asset: ${asset.title} (${asset.id})");

      final copied = await PhotoManager.editor.copyAssetToPath(
        asset: asset,
        pathEntity: selectedAlbum,
      );

      if (copied == null) {
        print("❌ copyAssetToPath retornó null para ${asset.title}");
        continue;
      }

      print("✅ Copiado correctamente: ${copied.title}");

      final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
      print("🗑️ Eliminado original: $deleted");

      movedCount++;
    } catch (e, st) {
      print("🔥 Error moviendo ${asset.title}: $e\n$st");
    }
  }

  if (movedCount > 0) {
    mostrarToast(context,
        "Se movieron $movedCount archivo(s) a '${selectedAlbum.name}'");
  } else {
    mostrarToast(context, "No se movió ningún archivo");
  }
}
