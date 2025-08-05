import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/pantallaCompleta.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';

// este widget carga la imagen predefinida para la el registro en la lista
Widget buildGrid({
  required BuildContext context,
  required List<AssetEntity> files,
  required bool isSel,
  required Set<String> selectedIds,
  required Set<String> favorites,
  required String folderName,
  required List<AssetEntity> currentList,
  required void Function() onReload,
  required void Function(Set<String>) onUpdateFavorites,
  required Function setState,
  required void Function(bool enable) onSelectionModeChanged,
}) {
  return SliverPadding(
    padding: const EdgeInsets.all(4),
    sliver: SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final file = files[index];
          return FutureBuilder<Uint8List?>(
            future: file.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
            builder: (_, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final isVideo = file.type == AssetType.video;
              final isSelected = selectedIds.contains(file.id);
              final isFavorite = favorites.contains(file.id);

              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final globalIndex = currentList.indexOf(file);

                      if (!isSel) {
                        final actualizado = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewerScreen(
                              files: currentList,
                              index: globalIndex,
                              nameFolder: folderName,
                            ),
                          ),
                        );

                        if (actualizado == true) {
                          onReload();
                        }
                      } else {
                        setState(() {
                          if (isSelected) {
                            selectedIds.remove(file.id);
                          } else {
                            selectedIds.add(file.id);
                          }
                        });
                      }
                    },
                    onLongPress: () {
                      if (!isSel) {
                        onSelectionModeChanged(
                            true); // ✅ activa selección si no estaba activa
                      }
                      setState(() {
                        if (isSelected) {
                          selectedIds.remove(file.id);
                        } else {
                          selectedIds.add(file.id);
                        }
                      });
                    },
                    child: ExtendedImage.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      cacheRawData: true,
                      opacity: AlwaysStoppedAnimation(isSelected ? 0.3 : 1.0),
                      border: Border.all(
                        color: isSel
                            ? isSelected
                                ? Colors.blueAccent
                                : Colors.transparent
                            : isFavorite
                                ? Colors.amber
                                : Colors.transparent,
                        width: 5,
                      ),
                    ),
                  ),

                  // ÍCONO DE FAVORITO o FULLSCREEN

                  Stack(
                    children: [
                      // ⭐ Ícono de estrella, siempre a la izquierda
                      Positioned(
                        top: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: () async {
                            final nuevosFavoritos =
                                await agregarFavorito(context, file);
                            onUpdateFavorites(nuevosFavoritos);
                          },
                          child: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: Colors.yellowAccent,
                          ),
                        ),
                      ),

                      // 🔍 Ícono de fullscreen, solo si isSel es true, siempre a la derecha
                      if (isSel)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              final globalIndex = currentList.indexOf(file);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ViewerScreen(
                                    files: currentList,
                                    index: globalIndex,
                                    nameFolder: folderName,
                                  ),
                                ),
                              );
                            },
                            child: const Icon(Icons.fullscreen,
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  // ÍCONO DE VIDEO + DURACIÓN
                  if (isVideo)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      left: 4,
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            formatoDeDuracion(file.videoDuration),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
        childCount: files.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
    ),
  );
}
