// ignore_for_file: avoid_print, use_build_context_synchronously, unnecessary_null_comparison, sort_child_properties_last, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors_in_immutables, prefer_interpolation_to_compose_strings, unused_local_variable

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nebula_vault/utils/listaImagenesMetodos.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:nebula_vault/widgets/gridImagenes.dart';
import 'package:nebula_vault/widgets/listaImagenesWidgets.dart';
import 'package:nebula_vault/widgets/moverSeleccionados.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:intl/intl.dart';
import 'pantallaCompleta.dart';

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
    _loadInitialData();
  }

  void _loadInitialData() async {
    final fav = await cargarFavoritos();
    final datos = await cargarArchivosDesdeFolder(widget.folder);

    setState(() {
      favorites = fav;
      files = datos.todos;
      images = datos.imagenes;
      gifs = datos.gifs;
      videos = datos.videos;

      groupedImages = datos.groupedImages;
      groupedGifs = datos.groupedGifs;
      groupedVideos = datos.groupedVideos;

      orderedImageDates = datos.fechasImagenes;
      orderedGifDates = datos.fechasGifs;
      orderedVideoDates = datos.fechasVideos;

      isLoading = false;
    });
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
          slivers: [
            buildGrid(
                context: context,
                files: files,
                isSel: isSel,
                selectedIds: selectedIds,
                favorites: favorites,
                folderName: widget.folder.name,
                currentList: files,
                onReload: _loadInitialData,
                onUpdateFavorites: (Set<String> newFavorites) {
                  setState(() {
                    favorites = newFavorites;
                  });
                },
                setState: setState)
          ],
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
            buildSectionHeader(
                date + " (" + grouped[date]!.length.toString() + ")",
                date,
                selectedDates,
                groupedImages,
                groupedGifs,
                groupedVideos,
                selectedIds,
                isSel,
                selectedFilter,
                setState),
            buildGrid(
                context: context,
                files: grouped[date]!,
                isSel: isSel,
                selectedIds: selectedIds,
                favorites: favorites,
                folderName: widget.folder.name,
                currentList: files,
                onReload: _loadInitialData,
                onUpdateFavorites: (Set<String> newFavorites) {
                  setState(() {
                    favorites = newFavorites;
                  });
                },
                setState: setState),
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
                          _loadInitialData(); // asumiendo que esta es una función sincrónica
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
                          _loadInitialData();
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
        onPressed: () async {
          final nuevoFiltro = await showFilterMenu(
              context, images, gifs, videos, selectedFilter);
          if (nuevoFiltro != null && nuevoFiltro != selectedFilter) {
            setState(() {
              selectedFilter = nuevoFiltro;
            });
          }
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.filter_alt_outlined, color: Colors.white),
        tooltip: 'Filtrar archivos',
      ),
    );
  }
}
