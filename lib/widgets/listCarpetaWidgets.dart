import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nebula_vault/screens/listaImagenes.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:nebula_vault/utils/listaCarpetaMetodos.dart';
import 'dart:typed_data';

Widget buildSubtitleAndIcons(Map<String, int> counts) {
  List<Widget> iconWidgets = [];

  if (counts['images']! > 0) {
    iconWidgets.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, size: 12, color: Colors.blueAccent),
        const SizedBox(width: 4),
        Text('${counts['images']}', style: const TextStyle(fontSize: 12)),
      ],
    ));
  }

  if (counts['gifs']! > 0) {
    iconWidgets.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.gif_box_outlined,
            size: 12, color: Colors.yellowAccent),
        const SizedBox(width: 4),
        Text('${counts['gifs']}', style: const TextStyle(fontSize: 12)),
      ],
    ));
  }

  if (counts['videos']! > 0) {
    iconWidgets.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam_outlined, size: 12, color: Colors.redAccent),
        const SizedBox(width: 4),
        Text('${counts['videos']}', style: const TextStyle(fontSize: 12)),
      ],
    ));
  }

  if (iconWidgets.isEmpty) {
    return const Text('Vacío');
  }

  // Agrupar los widgets en dos filas
  List<Widget> firstRow = [];
  List<Widget> secondRow = [];

  for (int i = 0; i < iconWidgets.length; i++) {
    if (iconWidgets.length == 2 || iconWidgets.length == 1) {
      final widget = Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            children: [
              iconWidgets[i],
              const SizedBox(height: 14), // Espacio
            ],
          ));
      firstRow.add(widget);
    } else {
      final widget = Padding(
        padding: const EdgeInsets.only(right: 8),
        child: iconWidgets[i],
      );

      if (i < 2) {
        firstRow.add(widget);
      } else {
        secondRow.add(widget);
      }
    }
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: firstRow),
      if (secondRow.isNotEmpty)
        Row(mainAxisSize: MainAxisSize.min, children: secondRow),
    ],
  );
}

Widget placeholderImage() {
  return Container(
    height: 100,
    width: double.infinity,
    color: Colors.grey.shade400,
    child: const Icon(Icons.image, size: 40, color: Colors.white),
  );
}

Widget loadingThumbnail() {
  return Container(
    height: 100,
    width: double.infinity,
    color: Colors.grey.shade300,
    child: const Center(child: CircularProgressIndicator()),
  );
}

Widget folderCardPlaceholder() {
  return Container(
    margin: const EdgeInsets.all(6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.grey.shade300,
    ),
    height: 150,
    width: double.infinity,
    child: const Center(child: CircularProgressIndicator()),
  );
}

Widget folderCardError(AssetPathEntity folder) {
  return Container(
    margin: const EdgeInsets.all(6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.red.shade300,
    ),
    height: 150,
    width: double.infinity,
    child: Center(
      child: Text(
        'Error al cargar "${folder.name}"',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

Widget buildFolderCard(
  AssetPathEntity folder,
  Map<String, String> folderThumbnailsMap,
  VoidCallback onRefresh,
  void Function(String) onFilter,
) {
  final customThumbId = folderThumbnailsMap[folder.name];

  final Future<AssetEntity?> portadaFuture = customThumbId != null
      ? AssetEntity.fromId(customThumbId)
      : Future.value(null);

  return FutureBuilder<AssetEntity?>(
    future: portadaFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return folderCardPlaceholder();
      }

      final portada = snapshot.data;

      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FileListScreen(folder: folder),
            ),
          );
          onRefresh(); // llama a loadInitialData
          onFilter(''); // o searchQuery si lo tienes disponible
        },
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade800,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (portada == null)
                placeholderImage()
              else
                FutureBuilder<Uint8List?>(
                  future: getSafeThumbnail(portada),
                  builder: (context, thumbSnap) {
                    if (thumbSnap.connectionState == ConnectionState.waiting) {
                      return loadingThumbnail();
                    }
                    final imageData = thumbSnap.data;
                    if (imageData != null) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imageData,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      );
                    }
                    return placeholderImage();
                  },
                ),
              const SizedBox(height: 8),
              Text(
                folder.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FutureBuilder<Map<String, int>>(
                future: countAssetsByType(folder),
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 16);
                  }
                  final counts = snapshot.data ?? {};
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      buildSubtitleAndIcons(counts),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
