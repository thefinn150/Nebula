import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';

class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> files;
  final int index;

  ViewerScreen({required this.files, required this.index});

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

  @override
  void initState() {
    super.initState();
    current = widget.index;
    _pageController = ExtendedPageController(initialPage: current);
    _prepareVideo();
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

  Future<void> _showDetails() async {
    final asset = widget.files[current];
    final file = await asset.file;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener el archivo')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final details = <String, String>{
          'Nombre': file.uri.pathSegments.last,
          'Ruta': file.path,
          'Tipo': asset.mimeType ?? 'Desconocido',
          'Tamaño':
              '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
          'Fecha creación': asset.createDateTime.toString(),
          'Fecha modificación': asset.modifiedDateTime.toString(),
          'Duración (seg)': asset.videoDuration.inSeconds.toString(),
          'ID': asset.id,
        };

        Widget detailRow(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child:
                      Text('$label:', style: TextStyle(color: Colors.white70)),
                ),
                Expanded(
                  flex: 5,
                  child: SelectableText(value,
                      style: TextStyle(color: Colors.white)),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.white70, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$label copiado al portapapeles')));
                  },
                ),
              ],
            ),
          );
        }

        return Container(
          padding: EdgeInsets.only(top: 16, bottom: 32),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  'Detalles del archivo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const Divider(color: Colors.white54),
                ...details.entries.map((e) => detailRow(e.key, e.value)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteCurrent() async {
    setState(() => isLoadingDelete = true);
    try {
      final asset = widget.files[current];
      final result = await PhotoManager.editor.deleteWithIds([asset.id]);
      if (result.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo eliminado correctamente')));
        // Quitar archivo de la lista localmente para refrescar la vista
        setState(() {
          widget.files.removeAt(current);
          if (current >= widget.files.length && current > 0) current--;
        });
        await _prepareVideo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar el archivo')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
    setState(() => isLoadingDelete = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
          child: Text(
            'No hay archivos para mostrar',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
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
        color: Colors.black.withOpacity(0.7),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Detalles
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              tooltip: 'Detalles del archivo',
              onPressed: _showDetails,
            ),

            // Eliminar
            isLoadingDelete
                ? CircularProgressIndicator(color: Colors.white)
                : IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Eliminar archivo',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Confirmar eliminación'),
                          content:
                              Text('¿Eliminar este archivo permanentemente?'),
                          actions: [
                            TextButton(
                              child: Text('Cancelar'),
                              onPressed: () => Navigator.pop(ctx, false),
                            ),
                            TextButton(
                              child: Text('Eliminar'),
                              onPressed: () => Navigator.pop(ctx, true),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await _deleteCurrent();
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
