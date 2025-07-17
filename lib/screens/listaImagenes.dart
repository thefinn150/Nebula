import 'dart:typed_data';
import 'package:flutter/material.dart';
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

class _FileListScreenState extends State<FileListScreen>
    with SingleTickerProviderStateMixin {
  final DateFormat dateFormat = DateFormat('dd MMM yyyy', 'es');

  late TabController _tabController;

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

  // Listado dinámico de tabs y labels según archivos existentes
  late List<Tab> tabs;
  late List<Widget> tabViews;

  @override
  void initState() {
    super.initState();

    // Inicializamos listas vacías para tabs, luego las llenaremos
    tabs = [];
    tabViews = [];

    _loadFiles();
  }

  void _initTabs() {
    tabs = [];
    tabViews = [];

    if (images.isNotEmpty) {
      tabs.add(const Tab(text: 'Imágenes'));
      tabViews.add(_buildTabContent(images, groupedImages, orderedImageDates));
    }
    if (gifs.isNotEmpty) {
      tabs.add(const Tab(text: 'GIFs'));
      tabViews.add(_buildTabContent(gifs, groupedGifs, orderedGifDates));
    }
    if (videos.isNotEmpty) {
      tabs.add(const Tab(text: 'Videos'));
      tabViews.add(_buildTabContent(videos, groupedVideos, orderedVideoDates,
          isVideoTab: true));
    }

    // Creamos el TabController con la cantidad dinámica de tabs
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Para mostrar/ocultar el switch cuando cambie de tab
      }
    });
  }

  Future<void> _loadFiles() async {
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
      images = tempImages;
      gifs = tempGifs;
      videos = tempVideos;

      groupedImages = _groupByDate(images);
      groupedGifs = _groupByDate(gifs);
      groupedVideos = _groupByDate(videos);

      orderedImageDates = groupedImages.keys.toList()
        ..sort((a, b) => dateFormat.parse(b).compareTo(dateFormat.parse(a)));

      orderedGifDates = groupedGifs.keys.toList()
        ..sort((a, b) => dateFormat.parse(b).compareTo(dateFormat.parse(a)));

      orderedVideoDates = groupedVideos.keys.toList()
        ..sort((a, b) => dateFormat.parse(b).compareTo(dateFormat.parse(a)));

      isLoading = false;

      // Inicializamos tabs ahora que ya tenemos datos
      _initTabs();
    });
  }

  Map<String, List<AssetEntity>> _groupByDate(List<AssetEntity> files) {
    final Map<String, List<AssetEntity>> map = {};
    for (var file in files) {
      final dateKey = dateFormat.format(file.createDateTime);
      map.putIfAbsent(dateKey, () => []).add(file);
    }
    return map;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
    } else {
      return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
    }
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
                        final currentList = _getCurrentList();
                        final globalIndex = currentList.indexOf(file);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewerScreen(
                              files: currentList,
                              index: globalIndex,
                            ),
                          ),
                        );
                      },
                      child: ExtendedImage.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheRawData: true,
                      ),
                    ),
                    if (isVideo)
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
                              _formatDuration(file.videoDuration),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
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

  List<AssetEntity> _getCurrentList() {
    if (_tabController.index >= tabViews.length) return [];

    if (tabs[_tabController.index].text == 'Imágenes') return images;
    if (tabs[_tabController.index].text == 'GIFs') return gifs;
    if (tabs[_tabController.index].text == 'Videos') {
      if (sortVideosByDuration) {
        List<AssetEntity> sortedVideos = List.from(videos)
          ..sort((a, b) => b.videoDuration.compareTo(a.videoDuration));
        return sortedVideos;
      }
      return videos;
    }
    return [];
  }

  Widget _buildTabContent(List<AssetEntity> files,
      Map<String, List<AssetEntity>> grouped, List<String> orderedDates,
      {bool isVideoTab = false}) {
    if (files.isEmpty) {
      return const Center(child: Text('No hay archivos'));
    }

    if (isVideoTab && sortVideosByDuration) {
      // Mostrar todos los videos ordenados por duración sin agrupar por fecha
      List<AssetEntity> sortedVideos = List.from(videos)
        ..sort((a, b) => b.videoDuration.compareTo(a.videoDuration));

      return CustomScrollView(
        slivers: [_buildGrid(sortedVideos)],
      );
    } else {
      // Mostrar videos (o imágenes/gifs) agrupados por fecha normalmente
      return CustomScrollView(
        slivers: [
          for (var date in orderedDates) ...[
            _buildSectionHeader(date),
            _buildGrid(grouped[date]!),
          ],
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (tabs.isEmpty) {
      // No hay archivos de ningún tipo
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.folder.name),
        ),
        body: const Center(
          child: Text('No hay archivos para mostrar'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs,
        ),
        actions: [
          if (tabs[_tabController.index].text == 'Videos' && videos.isNotEmpty)
            Row(
              children: [
                const Text('Ordenar por duración'),
                Switch(
                  value: sortVideosByDuration,
                  onChanged: (value) {
                    setState(() {
                      sortVideosByDuration = value;
                    });
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
    );
  }
}
