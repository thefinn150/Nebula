// ignore_for_file: override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/listaImagenes.dart';
import 'package:nebula_vault/utils/metodosGlobales.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:extended_image/extended_image.dart';
import 'package:nebula_vault/screens/pantallaCompleta.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _loadFavorites();
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
          child: ListView.builder(
            itemCount: filteredFolders.length,
            itemBuilder: (_, i) {
              final folder = filteredFolders[i];
              return FutureBuilder<Map<String, int>>(
                future: _countAssetsByType(folder),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(
                      title: Text(folder.name),
                      subtitle: const Text('Cargando...'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                    );
                  }

                  final counts = snapshot.data!;
                  return ListTile(
                    title: Text(folder.name),
                    subtitle: _buildSubtitleAndIcons(counts),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FileListScreen(folder: folder),
                      ),
                    ).then((_) async {
                      await _loadFolders();
                      _loadFavorites();
                      _filterFolders(
                          searchQuery); // <--- volver a aplicar filtro activo
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
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
      appBar: AppBar(
          title: Text('Favoritos' + " (" + favFiles.length.toString() + ")")),
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

                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ViewerScreen(files: favFiles, index: i),
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
                      ],
                    );
                  },
                );
              },
            ),
    );
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
