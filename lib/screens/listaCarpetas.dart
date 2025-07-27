// ignore_for_file: override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings, unused_local_variable

import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/listaImagenes.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:nebula_vault/screens/pantallaCompleta.dart';

import 'dart:convert';

class GaleriaHome extends StatefulWidget {
  @override
  _GaleriaHomeState createState() => _GaleriaHomeState();
}

class CustomAssetPath {
  final String name;
  final List<AssetEntity> assets;

  CustomAssetPath({required this.name, required this.assets});
}

class _GaleriaHomeState extends State<GaleriaHome> {
  List<AssetPathEntity> allFolders = [];
  List<AssetPathEntity> filteredFolders = [];
  bool isLoading = true;
  String searchQuery = '';
  int _selectedIndex = 0;
  Set<String> favorites = {};
  List<AssetEntity> favFiles = [];
  Map<String, String> folderThumbnailsMap = {}; // { carpetaNombre: fotoId }

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadFavorites();
    _loadFolderThumbnails();
  }

  Future<void> _loadFolderThumbnails() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString('folder_thumbnails');
    if (rawData != null) {
      try {
        final List<dynamic> list = jsonDecode(rawData);
        folderThumbnailsMap = {
          for (var entry in list) entry['carpeta']: entry['fotoId'],
        };
      } catch (e) {
        debugPrint('Error cargando portadas personalizadas: $e');
        folderThumbnailsMap = {};
      }
    } else {
      folderThumbnailsMap = {};
    }
    setState(() {});
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('favorites')?.toSet() ?? {};
    _loadFavs();
    setState(() {});
  }

  Future<void> _loadFavs() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('favorites') ?? [];
    final futures = ids.map((id) => AssetEntity.fromId(id));
    final results = await Future.wait(futures);
    setState(() {
      favFiles = results.whereType<AssetEntity>().toList();
    });
  }

  Future<void> _loadFolders() async {
    final result = await PhotoManager.requestPermissionExtend();
    if (!result.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final folders = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(),
        videoOption: const FilterOption(),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );

    folders
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    setState(() {
      allFolders = folders;
      filteredFolders = folders;
      isLoading = false;
    });
  }

  void _filterFolders(String query) {
    final result = allFolders
        .where(
            (folder) => folder.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      searchQuery = query;
      filteredFolders = result;
    });
  }

  Future<Map<String, int>> _countAssetsByType(AssetPathEntity folder) async {
    final count = await folder.assetCountAsync;
    final allAssets = await folder.getAssetListRange(start: 0, end: count);

    int imageCount = 0;
    int gifCount = 0;
    int videoCount = 0;

    for (var asset in allAssets) {
      if (asset.type == AssetType.video) {
        videoCount++;
      } else if (asset.type == AssetType.image) {
        if (asset.mimeType == 'image/gif') {
          gifCount++;
        } else {
          imageCount++;
        }
      }
    }

    return {
      'images': imageCount,
      'gifs': gifCount,
      'videos': videoCount,
    };
  }

  Widget _buildSubtitleAndIcons(Map<String, int> counts) {
    List<Widget> parts = [];

    if (counts['images']! > 0) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text('${counts['images']}'),
        ],
      ));
    }

    if (counts['gifs']! > 0) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎞️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text('${counts['gifs']}'),
        ],
      ));
    }

    if (counts['videos']! > 0) {
      parts.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_outlined,
              size: 16, color: Colors.redAccent),
          const SizedBox(width: 4),
          Text('${counts['videos']}'),
        ],
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts.isEmpty
          ? [const Text('Vacío')]
          : parts
              .map((w) =>
                  Padding(padding: const EdgeInsets.only(right: 8), child: w))
              .toList(),
    );
  }

  Widget _buildInicioView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            onChanged: _filterFolders,
            decoration: InputDecoration(
              hintText: 'Buscar carpeta...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (_) {
              final safeFilteredFolders =
                  List<AssetPathEntity>.from(filteredFolders);
              return ListView.builder(
                itemCount: (safeFilteredFolders.length / 2).ceil(),
                itemBuilder: (_, index) {
                  if (index * 2 >= safeFilteredFolders.length) {
                    return const SizedBox
                        .shrink(); // evita errores por índice inválido
                  }

                  final first = index * 2 < safeFilteredFolders.length
                      ? safeFilteredFolders[index * 2]
                      : null;

                  final second = index * 2 + 1 < safeFilteredFolders.length
                      ? safeFilteredFolders[index * 2 + 1]
                      : null;

                  return Row(
                    children: [
                      Expanded(
                        child: first != null
                            ? _buildFolderCard(first)
                            : const SizedBox(),
                      ),
                      if (second != null)
                        Expanded(child: _buildFolderCard(second))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFolderCard(AssetPathEntity folder) {
    final customThumbId = folderThumbnailsMap[folder.name];

    // Future para la portada a mostrar
    Future<AssetEntity?> portadaFuture;

    if (customThumbId != null) {
      portadaFuture = AssetEntity.fromId(customThumbId);
    } else {
      portadaFuture = folder.getAssetListRange(start: 0, end: 1).then(
            (assets) => assets.isNotEmpty ? assets.first : null,
          );
    }

    return FutureBuilder<AssetEntity?>(
      future: portadaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _folderCardPlaceholder();
        }

        if (snapshot.hasError) {
          return _folderCardError(folder);
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
            await _loadFolders();
            _loadFavorites();
            _loadFolderThumbnails();
            _filterFolders(searchQuery);
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
                  _placeholderImage()
                else
                  FutureBuilder<Uint8List?>(
                    future: _getSafeThumbnail(portada),
                    builder: (context, thumbSnap) {
                      if (thumbSnap.connectionState ==
                          ConnectionState.waiting) {
                        return _loadingThumbnail();
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
                      return _placeholderImage();
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
                  future: _countAssetsByType(folder),
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(height: 16);
                    }
                    final counts = snapshot.data ?? {};
                    return _buildSubtitleAndIcons(counts);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _getSafeThumbnail(AssetEntity asset) async {
    try {
      return await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
    } catch (e) {
      debugPrint('Error al generar thumbnail: $e');
      return null;
    }
  }

  Widget _placeholderImage() {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.grey.shade400,
      child: const Icon(Icons.image, size: 40, color: Colors.white),
    );
  }

  Widget _loadingThumbnail() {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _folderCardPlaceholder() {
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

  Widget _folderCardError(AssetPathEntity folder) {
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

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildInicioView();
    } else if (_selectedIndex == 1) {
      return isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildFavoritos(context);
    } else {
      return const Center(child: Text('Más (en construcción)'));
    }
  }

  @override
  Widget _buildFavoritos(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favoritos' + " (${favFiles.length})")),
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
                    final isImage = file.type == AssetType.image;
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
                              _loadFavorites();
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
                                  _formatDuration(file.videoDuration),
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

  /// 🔢 Utilidad para formatear duración de video
  String _formatDuration(Duration? duration) {
    if (duration == null) return "";
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nebula Vault')),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.shadow,
        enableFeedback: false,
        showSelectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
