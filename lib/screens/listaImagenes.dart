import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:intl/intl.dart';
import 'pantallaCompleta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

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

  bool isLoading = true;
  bool sortVideosByDuration = false;

  String selectedFilter = 'Imágenes'; // Imágenes, GIFs, Videos

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

  Future<void> _cargarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('favorites')?.toSet() ?? {};
    setState(() {});
  }

  Future<void> _agregarFavorito(AssetEntity file) async {
    final prefs = await SharedPreferences.getInstance();
    final id = file.id;

    // Convertir a Set correctamente
    Set<String> favorites = (prefs.getStringList('favorites') ?? []).toSet();

    if (favorites.contains(id)) {
      favorites.remove(id);
      showToast(context, "Eliminado de favoritos");
    } else {
      favorites.add(id);
      showToast(context, "Agregado a favoritos");
    }

    await prefs.setStringList('favorites', favorites.toList());

    setState(() {
      // Si tu variable de clase es también Set<String>
      this.favorites = favorites;
    });
  }

  Future<void> _borrarSeleccionados() async {
    if (selectedIds.isEmpty) return;

    try {
      final result =
          await PhotoManager.editor.deleteWithIds(selectedIds.toList());

      if (result.isNotEmpty) {
        showToast(context, "Se eliminaron ${result.length} elementos");
      } else {
        showToast(context, "No se pudo eliminar ninguno");
      }
    } catch (e) {
      showToast(context, "Error al eliminar: $e");
    }

    selectedIds.clear();
    _cargarArchivos();
  }

  Future<void> _moverSeleccionados() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      showToast(context, "No tienes permisos suficientes");
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
                .where(
                    (a) => a.name.toLowerCase().contains(filter.toLowerCase()))
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
      showToast(context, "No hay archivos válidos para mover");
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
      showToast(context,
          "Se movieron $movedCount archivo(s) a '${selectedAlbum.name}'");
    } else {
      showToast(context, "No se movió ningún archivo");
    }

    selectedIds.clear();
    await _cargarArchivos();
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

      groupedImages = _agruparPorFecha(images);
      groupedGifs = _agruparPorFecha(gifs);
      groupedVideos = _agruparPorFecha(videos);

      orderedImageDates = _obtenerFechasOrdenadas(groupedImages);
      orderedGifDates = _obtenerFechasOrdenadas(groupedGifs);
      orderedVideoDates = _obtenerFechasOrdenadas(groupedVideos);

      isLoading = false;
    });
  }

  Future<String?> _buscarNombreCarpeta(BuildContext ctx, String title) async {
    String name = '';
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(onChanged: (v) => name = v),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, name), child: Text("OK")),
        ],
      ),
    );
  }

  Map<String, List<AssetEntity>> _agruparPorFecha(List<AssetEntity> files) {
    final Map<String, List<AssetEntity>> map = {};
    for (var file in files) {
      final dateKey = dateFormat.format(file.modifiedDateTime);
      map.putIfAbsent(dateKey, () => []).add(file);
    }
    return map;
  }

  List<String> _obtenerFechasOrdenadas(Map<String, List<AssetEntity>> grouped) {
    final keys = grouped.keys.toList();
    keys.sort((a, b) => dateFormat.parse(b).compareTo(dateFormat.parse(a)));
    return keys;
  }

  String _formatoDeDuracion(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
    } else {
      return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
    }
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

  void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.black,
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                      onTap: () {
                        // Aquí cambiamos para pasar la lista ordenada y el índice correcto
                        final currentList = _getOrderedVisibleList();
                        final globalIndex = currentList.indexOf(file);
                        !isSel
                            ? Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ViewerScreen(
                                    files: currentList,
                                    index: globalIndex,
                                  ),
                                ),
                              )
                            : setState(() {
                                isSel = true;
                                final id = file.id;
                                if (selectedIds.contains(id)) {
                                  selectedIds.remove(id);
                                } else {
                                  selectedIds.add(id);
                                }
                              });
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
                          width: 3,
                        ),
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheRawData: true,
                      ),
                    ),
                    if (isVideo)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _agregarFavorito(file),
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
                                  _formatoDeDuracion(file.videoDuration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    else
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _agregarFavorito(file),
                          child: Icon(
                            favorites.contains(file.id)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.yellowAccent,
                          ),
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

    return Scrollbar(
      interactive: true,
      thickness: 30,
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (var date in orderedDates) ...[
            _buildSectionHeader(date),
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
        title: Text(widget.folder.name),
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
                      await _moverSeleccionados();
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
                      await _borrarSeleccionados();
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
                    duration: Duration(milliseconds: 300),
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
                                offset: Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    padding: EdgeInsets.all(6), // Más compacto
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
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
