// ignore_for_file: use_build_context_synchronously, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors_in_immutables, prefer_interpolation_to_compose_strings

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nebula_vault/utils/detallesArchivo.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> files;
  final int index;
  final String nameFolder;

  ViewerScreen(
      {required this.files, required this.index, required this.nameFolder});

  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late ExtendedPageController _pageController;
  int current = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool isLoadingMove = false;
  bool isLoadingDelete = false;

  Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    current = widget.index;

    current = widget.index;
    _pageController = ExtendedPageController(initialPage: current);
    _prepareVideo();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('favorites')?.toSet() ?? {};
    setState(() {});
  }

  Future<void> _prepareVideo() async {
    _videoController?.dispose();
    _chewieController?.dispose();

    final file = await widget.files[current].file;
    if (widget.files[current].type == AssetType.video && file != null) {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        zoomAndPan: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white70,
        ),
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );

      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey.withOpacity(0.1),
        appBar: AppBar(
          backgroundColor: Colors.grey.withOpacity(0.1),
        ),
        body: const Center(
          child: Text(
            'No hay archivos para mostrar',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.withOpacity(0.1),
      appBar: AppBar(
        backgroundColor: Colors.grey.withOpacity(0.1),
      ),
      body: ExtendedImageGesturePageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (i) async {
          setState(() => current = i);
          await _prepareVideo();
        },
        itemBuilder: (_, i) {
          final file = widget.files[i];

          if (file.type == AssetType.image || file.type == AssetType.audio) {
            return FutureBuilder<File?>(
              future: file.file,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ExtendedImage.file(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  mode: ExtendedImageMode.gesture,
                  enableSlideOutPage: false,
                  initGestureConfigHandler: (_) => GestureConfig(
                    minScale: 1.0,
                    maxScale: 4.0,
                    animationMinScale: 0.7,
                    animationMaxScale: 4.5,
                    speed: 1.0,
                    inertialSpeed: 100.0,
                    initialScale: 1.0,
                    inPageView: true,
                    initialAlignment: InitialAlignment.center,
                    cacheGesture: false,
                  ),
                );
              },
            );
          } else if (file.type == AssetType.video) {
            return _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? Center(child: Chewie(controller: _chewieController!))
                : const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text("Formato no soportado"));
          }
        },
      ),

      // Botones discretos en la parte inferior:
      bottomNavigationBar: Container(
        color: favorites.contains(widget.files[current].id)
            ? Colors.yellow.withOpacity(0.3)
            : Colors.grey.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Eliminar
            isLoadingDelete
                ? const CircularProgressIndicator(color: Colors.white)
                : IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: 'Eliminar archivo',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.5),
                    ),
                    focusColor: Colors.redAccent,
                    splashColor: Colors.red,
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text(
                              '¿Eliminar este archivo permanentemente?'),
                          actions: [
                            TextButton(
                              child: const Text('Cancelar'),
                              onPressed: () => Navigator.pop(ctx, false),
                            ),
                            TextButton(
                              child: const Text('Eliminar'),
                              onPressed: () => Navigator.pop(ctx, true),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        isLoadingDelete =
                            await borrarActual(context, widget.files[current]);
                        Navigator.pop(context, true);
                      }
                    },
                  ),

            ElevatedButton(
              onPressed: () async {
                await setFolderThumbnail(
                  context: context,
                  folderName: widget.nameFolder,
                  asset: widget.files[current],
                );
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
              ),
              child: Text(
                '${current + 1}', // Mostrar el número humano (inicia en 1)
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            IconButton(
              icon: favorites.contains(widget.files[current].id)
                  ? const Icon(Icons.star, color: Colors.yellowAccent)
                  : const Icon(Icons.star_border, color: Colors.white),
              tooltip: 'Agregar a favoritos',
              style: IconButton.styleFrom(
                backgroundColor: favorites.contains(widget.files[current].id)
                    ? Colors.yellowAccent.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.5),
              ),
              focusColor: Colors.yellowAccent,
              splashColor: Colors.yellow,
              onPressed: () async {
                favorites =
                    await agregarFavorito(context, widget.files[current]);
                _cargarFavoritos();
                setState(() {});
              },
            ),

            IconButton(
              icon: //favorites.contains(widget.files[current].id)
                  const Icon(Icons.image_outlined, color: Colors.white),
              tooltip: 'Agregar a favoritos',
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              focusColor: Colors.white,
              splashColor: Colors.white,
              onPressed: () async {
                await setFolderThumbnail(
                  context: context,
                  folderName: widget.nameFolder,
                  asset: widget.files[current],
                );

                setState(() {});
              },
            ),

            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              tooltip: 'Detalles del archivo',
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.5),
              ),
              focusColor: Colors.blueAccent,
              splashColor: Colors.blue,
              onPressed: () => mostrarDetalles(context, widget.files[current]),
            ),
          ],
        ),
      ),
    );
  }
}
