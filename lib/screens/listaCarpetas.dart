// ignore_for_file: override_on_non_overriding_member, prefer_adjacent_string_concatenation, prefer_interpolation_to_compose_strings, unused_local_variable

import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/favoritos.dart';
import 'package:nebula_vault/utils/listaCarpetaMetodos.dart';
import 'package:nebula_vault/widgets/listCarpetaWidgets.dart';
import 'package:photo_manager/photo_manager.dart';

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
  Map<String, String> folderThumbnailsMap = {};
  List<String> prioridad = [
    'Screenshots',
    'Download',
    'Camera',
    'Facebook',
    'Pictures',
    'Twitter',
    'Movies',
    'Twitter',
    'WhatsApp Animated Gifs',
    'WhatsApp Images',
    'WhatsApp Video'
  ];

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  void loadInitialData() async {
    await _loadFolders();

    final fav = await loadFavorites();
    final map = await loadFolderThumbnails();
    final favFilesload = await loadFavs();
    setState(() {
      folderThumbnailsMap = map;
      favorites = fav;
      favFiles = favFilesload;
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
    folders.sort((a, b) {
      final aIsPrioritario = prioridad.contains(a.name);
      final bIsPrioritario = prioridad.contains(b.name);

      if (aIsPrioritario && !bIsPrioritario) return -1;
      if (!aIsPrioritario && bIsPrioritario) return 1;

      // Si ambos son prioritarios o ninguno lo es, orden alfabético
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

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
              final prioritarias = filteredFolders
                  .where((f) => prioridad.contains(f.name))
                  .toList();
              final otras = filteredFolders
                  .where((f) => !prioridad.contains(f.name))
                  .toList();

              List<Widget> buildFolderRows(List<AssetPathEntity> folders) {
                return List.generate((folders.length / 2).ceil(), (index) {
                  final first = folders[index * 2];
                  final second = (index * 2 + 1 < folders.length)
                      ? folders[index * 2 + 1]
                      : null;

                  return Row(
                    children: [
                      Expanded(
                          child: buildFolderCard(
                        first,
                        folderThumbnailsMap,
                        loadInitialData,
                        _filterFolders,
                      )),
                      if (second != null)
                        Expanded(
                            child: buildFolderCard(
                          second,
                          folderThumbnailsMap,
                          loadInitialData,
                          _filterFolders,
                        ))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  );
                });
              }

              return ListView(
                children: [
                  ...buildFolderRows(prioritarias),
                  if (prioritarias.isNotEmpty && otras.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          Expanded(child: Divider(thickness: 1)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "Otras carpetas",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider(thickness: 1)),
                        ],
                      ),
                    ),
                  ...buildFolderRows(otras),
                ],
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
          : buildFavoritos(context, favFiles, favorites, loadInitialData);
    } else {
      return const Center(child: Text('Más (en construcción)'));
    }
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
