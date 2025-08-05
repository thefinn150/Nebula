// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as p;
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:media_scanner/media_scanner.dart';

Future<void> moverSeleccionados(BuildContext context, Set<String> selectedIds,
    List<AssetEntity> files) async {
  final permission = await PhotoManager.requestPermissionExtend();
  if (!permission.isAuth) {
    mostrarToast(context, "No tienes permisos suficientes");
    return;
  }

  Directory? destino;

  await showDialog(
    context: context,
    builder: (ctx) {
      final TextEditingController searchController = TextEditingController();
      final TextEditingController nuevaCarpetaController =
          TextEditingController();
      String filter = '';
      Directory base = Directory('/storage/emulated/0/NebulaVault');

      List<Directory> subcarpetas = base
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path
              .split("/")
              .last
              .toLowerCase()
              .contains(filter.toLowerCase()))
          .toList();

      void actualizar() {
        subcarpetas = base
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path
                .split("/")
                .last
                .toLowerCase()
                .contains(filter.toLowerCase()))
            .toList();
      }

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Selecciona carpeta destino"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: "Filtrar carpeta",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      filter = v;
                      setState(actualizar);
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: subcarpetas.length,
                      itemBuilder: (_, i) {
                        final carpeta = subcarpetas[i];
                        final nombre = carpeta.path.split("/").last;
                        return ListTile(
                          title: Text(nombre),
                          onTap: () {
                            destino = carpeta;
                            Navigator.pop(ctx);
                          },
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
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final nombre = await showDialog<String>(
                    context: context,
                    builder: (ctx2) {
                      return AlertDialog(
                        title: const Text("Nombre de nueva carpeta"),
                        content: TextField(
                          controller: nuevaCarpetaController,
                          decoration:
                              const InputDecoration(hintText: "Ej. MisFotos"),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx2),
                            child: const Text("Cancelar"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(
                                ctx2, nuevaCarpetaController.text.trim()),
                            child: const Text("Crear"),
                          ),
                        ],
                      );
                    },
                  );

                  if (nombre != null && nombre.isNotEmpty) {
                    final nuevaRuta = Directory('${base.path}/$nombre'.trim());

                    if (!(await nuevaRuta.exists())) {
                      await nuevaRuta.create(recursive: true);
                    }

                    destino = nuevaRuta;
                    mostrarToast(context, "Carpeta creada y seleccionada");
                    Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.create_new_folder),
                label: const Text("Nueva carpeta"),
              )
            ],
          );
        },
      );
    },
  );

  if (destino == null) return;

  final fileMap = {for (var f in files) f.id: f};
  selectedIds = selectedIds.where((id) => fileMap.containsKey(id)).toSet();

  if (selectedIds.isEmpty) {
    mostrarToast(context, "No hay archivos válidos para mover");
    return;
  }

  int movedCount = 0;

  for (final id in selectedIds) {
    final asset = fileMap[id];
    if (asset == null) continue;

    try {
      final archivoOriginal = await asset.file;
      if (archivoOriginal == null) continue;

      final nombre = p.basename(archivoOriginal.path);
      final destinoFinal = File('${destino!.path}/$nombre');

      // Copia el archivo al destino
      await archivoOriginal.copy(destinoFinal.path);

// ✅ Forzar escaneo para que Android lo indexe
      await MediaScanner.loadMedia(path: destinoFinal.path);

      AssetEntity? nuevoAsset;
      if (asset.type == AssetType.image) {
        nuevoAsset =
            await PhotoManager.editor.saveImageWithPath(destinoFinal.path);
      } else if (asset.type == AssetType.video) {
        nuevoAsset = await PhotoManager.editor.saveVideo(destinoFinal);
      }

      if (nuevoAsset == null) {
        print("⚠️ No se pudo indexar en MediaStore: ${destinoFinal.path}");
        continue;
      }

// Borra el original de la galería
      await PhotoManager.editor.deleteWithIds([asset.id]);

      movedCount++;
      print("✅ Movido a ${destinoFinal.path}");
    } catch (e, st) {
      print("❌ Error al mover $id: $e\n$st");
    }
  }

  if (movedCount > 0) {
    await PhotoManager.clearFileCache();

    mostrarToast(context,
        "Se movieron $movedCount archivo(s) a '${destino!.path.split("/").last}'");
  } else {
    mostrarToast(context, "No se movió ningún archivo");
  }

  await PhotoManager.clearFileCache();
}
