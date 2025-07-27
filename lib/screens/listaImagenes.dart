// ignore_for_file: avoid_print, use_build_context_synchronously, unnecessary_null_comparison, sort_child_properties_last, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors_in_immutables, prefer_interpolation_to_compose_strings

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nebula_vault/utils/listaImagenesMetodos.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:nebula_vault/widgets/moverSeleccionados.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:intl/intl.dart';
import 'pantallaCompleta.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileListScreen extends StatefulWidget {
  final AssetPathEntity folder;
  FileListScreen({required this.folder});

  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<AssetEntity> files = [];
  final DateFormat dateFormat = DateFormat('dd MMM yyyy', 'es');

  List<AssetEntity> images = [];
  List<AssetEntity> gifs = [];
  List<AssetEntity> videos = [];

  Map<String, List<AssetEntity>> groupedImages = {};
  Map<String, List<AssetEntity>> groupedGifs = {};
  Map<String, List<AssetEntity>> groupedVideos = {};

  List<String> orderedImageDates = [];
  List<String> orderedGifDates = [];
  List<String> orderedVideoDates = [];

  List<String> selectedDates = [];

  bool isLoading = true;
  bool sortVideosByDuration = false;

  String selectedFilter = 'Imágenes';

  Set<String> selectedIds = {};
  Set<String> favorites = {};
  bool isSel = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    pedirPermisosCompletos();
    _cargarArchivos();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('favorites')?.toSet() ?? {};
    setState(() {});
  }

  Future<void> _cargarArchivos() async {
    final allFiles =
        await widget.folder.getAssetListPaged(page: 0, size: 10000);

    List<AssetEntity> tempImages = [];
    List<AssetEntity> tempGifs = [];
    List<AssetEntity> tempVideos = [];

    for (var file in allFiles) {
      if (file.type == AssetType.video) {
        tempVideos.add(file);
      } else if (file.type == AssetType.image) {
        if (file.mimeType == 'image/gif') {
          tempGifs.add(file);
        } else {
          tempImages.add(file);
        }
      }
    }

    setState(() {
      files = allFiles;
      images = tempImages;
      gifs = tempGifs;
      videos = tempVideos;

      groupedImages = agruparPorFecha(images);
      groupedGifs = agruparPorFecha(gifs);
      groupedVideos = agruparPorFecha(videos);

      orderedImageDates = obtenerFechasOrdenadas(groupedImages);
      orderedGifDates = obtenerFechasOrdenadas(groupedGifs);
      orderedVideoDates = obtenerFechasOrdenadas(groupedVideos);

      isLoading = false;
    });
  }

  List<AssetEntity> _getOrderedVisibleList() {
    final Map<String, List<AssetEntity>> grouped = {
      'Imágenes': groupedImages,
      'GIFs': groupedGifs,
      'Videos': groupedVideos,
    }[selectedFilter]!;

    final List<String> orderedDates = {
      'Imágenes': orderedImageDates,
      'GIFs': orderedGifDates,
      'Videos': orderedVideoDates,
    }[selectedFilter]!;

    List<AssetEntity> orderedList = [];
    for (var date in orderedDates) {
      orderedList.addAll(grouped[date]!);
    }
    return orderedList;
  }

  List<AssetEntity> _getCurrentList() {
    if (orderedImageDates.isEmpty && orderedVideoDates.isEmpty) {
      selectedFilter = 'GIFs';
    } else if (orderedImageDates.isEmpty && orderedGifDates.isEmpty) {
      selectedFilter = 'Videos';
    } else if (orderedGifDates.isEmpty && orderedVideoDates.isEmpty) {
      selectedFilter = 'Imágenes';
    }

    switch (selectedFilter) {
      case 'GIFs':
        return gifs;
      case 'Videos':
        if (sortVideosByDuration) {
          List<AssetEntity> sortedVideos = List.from(videos)
            ..sort((a, b) => b.videoDuration.compareTo(a.videoDuration));
          return sortedVideos;
        }
        return videos;
      case 'Imágenes':
      default:
        return images;
    }
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Filtrar por tipo de archivo',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const Divider(color: Colors.white24),
            for (String type in ['Imágenes', 'GIFs', 'Videos'])
              if ((type == 'Imágenes' && images.isNotEmpty) ||
                  (type == 'GIFs' && gifs.isNotEmpty) ||
                  (type == 'Videos' && videos.isNotEmpty))
                ListTile(
                  title:
                      Text(type, style: const TextStyle(color: Colors.white)),
                  trailing: selectedFilter == type
                      ? const Icon(Icons.check, color: Colors.lightBlueAccent)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedFilter = type;
                    });
                  },
                ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String date) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: selectedDates.contains(date)
                  ? Icon(Icons.circle_rounded, color: Colors.blueAccent)
                  : Icon(Icons.circle_outlined, color: Colors.white),
              onPressed: () async {
                selectedDates.contains(date)
                    ? selectedDates.remove(date)
                    : selectedDates.add(date);

                setState(() {});
                final Map<String, List<AssetEntity>> grouped = {
                  'Imágenes': groupedImages,
                  'GIFs': groupedGifs,
                  'Videos': groupedVideos,
                }[selectedFilter]!;

                if (!selectedDates.contains(date)) {
                  for (var asset in grouped[date]!) {
                    selectedIds.remove(asset.id);
                  }
                } else {
                  for (var asset in grouped[date]!) {
                    selectedIds.add(asset.id);
                  }
                }
                print("*****************" + selectedIds.toString());
                isSel = true;
                print("*****************" + isSel.toString());
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<AssetEntity> files) {
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
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final currentList = _getOrderedVisibleList();
                        final globalIndex = currentList.indexOf(file);

                        if (!isSel) {
                          final actualizado = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewerScreen(
                                files: currentList,
                                index: globalIndex,
                              ),
                            ),
                          );

                          if (actualizado == true) {
                            _cargarArchivos();
                            _cargarFavoritos();
                          }
                        } else {
                          setState(() {
                            isSel = true;
                            final id = file.id;
                            if (selectedIds.contains(id)) {
                              selectedIds.remove(id);
                            } else {
                              selectedIds.add(id);
                            }
                          });
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          isSel = true;
                          final id = file.id;
                          if (selectedIds.contains(id)) {
                            selectedIds.remove(id);
                          } else {
                            selectedIds.add(id);
                          }
                        });
                      },
                      child: ExtendedImage.memory(
                        border: Border.all(
                          color: isSel
                              ? selectedIds.contains(file.id)
                                  ? Colors.blueAccent
                                  : Colors.transparent
                              : favorites.contains(file.id)
                                  ? Colors.amber
                                  : Colors.transparent,
                          width: 5,
                        ),
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheRawData: true,
                        opacity: selectedIds.contains(file.id)
                            ? const AlwaysStoppedAnimation(0.3)
                            : const AlwaysStoppedAnimation(1.0),
                      ),
                    ),
                    if (isVideo)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isSel == false)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () async {
                                  favorites =
                                      await agregarFavorito(context, file);
                                  setState(() {});
                                },
                                child: Icon(
                                  favorites.contains(file.id)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.yellowAccent,
                                ),
                              ),
                            ),
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
                          )
                        ],
                      )
                    else if (isSel == false)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            favorites = await agregarFavorito(context, file);
                            setState(() {});
                          },
                          child: Icon(
                            favorites.contains(file.id)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.yellowAccent,
                          ),
                        ),
                      )
                    else if (isSel == true)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            final currentList = _getOrderedVisibleList();
                            final globalIndex = currentList.indexOf(file);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewerScreen(
                                  files: currentList,
                                  index: globalIndex,
                                ),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                          ),
                        ),
                      )
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

  Widget _buildContent() {
    final files = _getCurrentList();

    if (files.isEmpty) {
      return const Center(child: Text('No hay archivos para mostrar'));
    }

    if (selectedFilter == 'Videos' && sortVideosByDuration) {
      return Scrollbar(
        controller: _scrollController,
        interactive: true,
        thickness: 30,
        scrollbarOrientation: ScrollbarOrientation.left,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [_buildGrid(files)],
        ),
      );
    }

    final Map<String, List<AssetEntity>> grouped = {
      'Imágenes': groupedImages,
      'GIFs': groupedGifs,
      'Videos': groupedVideos,
    }[selectedFilter]!;

    final List<String> orderedDates = {
      'Imágenes': orderedImageDates,
      'GIFs': orderedGifDates,
      'Videos': orderedVideoDates,
    }[selectedFilter]!;

    final int itemCount = orderedDates.isEmpty
        ? 0
        : orderedDates
            .map((date) => grouped[date]!.length)
            .reduce((a, b) => a + b);

    return Scrollbar(
      interactive: true,
      thickness: 30,
      controller: _scrollController,
      scrollbarOrientation: ScrollbarOrientation.left,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (var date in orderedDates) ...[
            _buildSectionHeader(
                date + " (" + grouped[date]!.length.toString() + ")", date),
            _buildGrid(grouped[date]!),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !isSel
            ? Text(widget.folder.name + " (" + files.length.toString() + ")")
            : Text(" (" +
                selectedIds.length.toString() +
                " de " +
                files.length.toString() +
                ")"),
        actions: [
          Row(
            children: [
              if (selectedFilter == 'Videos' && videos.isNotEmpty)
                const Text('Duración', style: TextStyle(color: Colors.white)),
              if (selectedFilter == 'Videos' && videos.isNotEmpty)
                Switch(
                  value: sortVideosByDuration,
                  onChanged: (value) {
                    setState(() {
                      sortVideosByDuration = value;
                    });
                  },
                ),
              if (selectedFilter == 'Videos' && videos.isNotEmpty)
                const SizedBox(width: 12),
              if (isSel == true && selectedIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.drive_folder_upload,
                      color: Colors.blueAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("¿Mover elementos?"),
                        content: const Text(
                            "Se moveran a la carpeta que selecciones."),
                        actions: [
                          TextButton(
                            child: const Text("Cancelar"),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: const Text("Mover"),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await moverSeleccionados(context, selectedIds, files)
                          .then((_) {
                        setState(() {
                          isSel = false;
                          selectedIds.clear();
                          _cargarArchivos(); // asumiendo que esta es una función sincrónica
                        });
                      });
                    }
                  },
                ),
              if (isSel == true && selectedIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("¿Eliminar archivos?"),
                        content: const Text(
                            "Esta acción eliminará los archivos seleccionados de forma permanente."),
                        actions: [
                          TextButton(
                            child: const Text("Cancelar"),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          TextButton(
                            child: const Text("Eliminar"),
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await borrarSeleccionados(context, selectedIds).then((_) {
                        setState(() {
                          isSel = false;
                          selectedIds.clear();
                          _cargarArchivos();
                        });
                      });
                    }
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isSel = !isSel;
                      if (isSel == false) {
                        selectedIds.clear();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? Colors.blueAccent : Colors.transparent,
                      border: Border.all(
                        color: isSel ? Colors.blueAccent : Colors.white60,
                        width: 1.5,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(6), // Más compacto
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: Icon(
                        isSel ? Icons.check : Icons.radio_button_unchecked,
                        key: ValueKey<bool>(isSel),
                        color: Colors.white,
                        size: 20, // Más pequeño y limpio
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterMenu,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.filter_alt_outlined, color: Colors.white),
        tooltip: 'Filtrar archivos',
      ),
    );
  }
}
