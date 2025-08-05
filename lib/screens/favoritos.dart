import 'package:flutter/material.dart';
import 'package:nebula_vault/utils/listaCarpetaMetodos.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'dart:typed_data';
import 'package:nebula_vault/screens/pantallaCompleta.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';

Widget buildFavoritos(
  BuildContext context,
  List<AssetEntity> favFiles,
  Set<String> favorites,
  VoidCallback onFavoritoActualizado, // 💡 callback recibido
) {
  return Scaffold(
    appBar: AppBar(title: Text('Favoritos (${favFiles.length})')),
    body: favFiles.isEmpty
        ? const Center(child: Text('No hay favoritos'))
        : GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: favFiles.length,
            itemBuilder: (_, i) {
              final file = favFiles[i];
              return FutureBuilder<Uint8List?>(
                future:
                    file.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();

                  final isVideo = file.type == AssetType.video;
                  //final isImage = file.type == AssetType.image;
                  final isGif =
                      file.title?.toLowerCase().endsWith('.gif') ?? false;

                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewerScreen(
                                files: favFiles,
                                index: i,
                                nameFolder: 'favoritos',
                              ),
                            ),
                          );
                        },
                        child: ExtendedImage.memory(
                          snap.data!,
                          fit: BoxFit.cover,
                          cacheRawData: true,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),

                      // ⭐️ Ícono de favorito
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            favorites = await agregarFavorito(context, file);
                            onFavoritoActualizado(); // 💥 actualiza desde GaleriaHome
                          },
                          child: Icon(
                            favorites.contains(file.id)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.yellowAccent,
                          ),
                        ),
                      ),

                      // 🎬 Icono de video + duración
                      if (isVideo)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Icon(Icons.videocam,
                                  color: Colors.white, size: 18),
                              Text(
                                formatDuration(file.videoDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 🖼 Etiqueta para GIFs
                      if (isGif)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 6),
                            color: Colors.black54,
                            child: const Text(
                              'GIF',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
  );
}
