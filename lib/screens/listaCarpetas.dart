import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/listaImagenes.dart';
import 'package:photo_manager/photo_manager.dart';

class GaleriaHome extends StatefulWidget {
  @override
  _GaleriaHomeState createState() => _GaleriaHomeState();
}

class _GaleriaHomeState extends State<GaleriaHome> {
  List<AssetPathEntity> allFolders = [];
  List<AssetPathEntity> filteredFolders = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFolders();
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
          const Text('🎞️', style: TextStyle(fontSize: 16)), // emoji gif
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nebula Vault')),
      body: Column(
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
