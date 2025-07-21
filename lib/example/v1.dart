import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(GaleriaApp());

class GaleriaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galería',
      theme: ThemeData.dark(useMaterial3: true),
      home: GaleriaHome(),
    );
  }
}

class GaleriaHome extends StatefulWidget {
  @override
  _GaleriaHomeState createState() => _GaleriaHomeState();
}

class _GaleriaHomeState extends State<GaleriaHome> {
  List<AssetPathEntity> folders = [];
  bool isLoading = true;

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

    final all = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(),
        videoOption: const FilterOption(),
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );

    setState(() {
      folders = all;
      isLoading = false;
    });
  }

  Future<void> _renameFolder(AssetPathEntity folder) async {
    final assets = await folder.getAssetListRange(start: 0, end: 1);
    if (assets.isEmpty) {
      Fluttertoast.showToast(msg: 'Carpeta vacía');
      return;
    }
    final file = await assets.first.file;
    if (file == null) return;
    final oldDir = file.parent;

    final newName = await _askFolderName(context, 'Nuevo nombre de carpeta');
    if (newName == null || newName.trim().isEmpty) return;

    final newDir = Directory('${oldDir.parent.path}/$newName');
    if (!await newDir.exists()) await newDir.create();
    await oldDir.rename(newDir.path);

    Fluttertoast.showToast(msg: "Carpeta renombrada");
    _loadFolders();
  }

  Future<String?> _askFolderName(BuildContext ctx, String title) async {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Galería')),
      body: ListView.builder(
        itemCount: folders.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return ListTile(
              leading: Icon(Icons.star),
              title: Text('⭐ Favoritos'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FavoritesScreen()),
              ),
            );
          }
          final folder = folders[i - 1];
          return ListTile(
            title: Text(folder.name),
            subtitle: FutureBuilder<int>(
              future: folder.assetCountAsync,
              builder: (_, snap) => Text('${snap.data ?? 0} archivos'),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'renombrar') _renameFolder(folder);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'renombrar', child: Text('Renombrar carpeta')),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FileListScreen(folder: folder)),
            ),
          );
        },
      ),
    );
  }
}

class FileListScreen extends StatefulWidget {
  final AssetPathEntity folder;
  FileListScreen({required this.folder});

  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<AssetEntity> files = [];
  Set<int> selected = {};
  Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadFavorites();
  }

  Future<void> _loadFiles() async {
    final f = await widget.folder.getAssetListPaged(page: 0, size: 10000);
    setState(() => files = f);
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    favorites = prefs.getStringList('favorites')?.toSet() ?? {};
    setState(() {});
  }

  Future<void> _toggleFavorite(AssetEntity file) async {
    final prefs = await SharedPreferences.getInstance();
    final id = file.id;
    if (favorites.contains(id)) {
      favorites.remove(id);
      Fluttertoast.showToast(msg: "Quitado de favoritos");
    } else {
      favorites.add(id);
      Fluttertoast.showToast(msg: "Agregado a favoritos");
    }
    await prefs.setStringList('favorites', favorites.toList());
    setState(() {});
  }

  Future<void> _deleteSelected() async {
    for (var i in selected) {
      final f = await files[i].file;
      if (f != null) await f.delete();
    }
    Fluttertoast.showToast(msg: "Eliminadas");
    selected.clear();
    _loadFiles();
  }

  Future<void> _moveSelected() async {
    final carpeta = await _askFolderName(context, 'Mover a carpeta');
    if (carpeta == null || carpeta.trim().isEmpty) return;
    for (var i in selected) {
      final f = await files[i].file;
      if (f == null) continue;
      final parent = f.parent;
      final newDir = Directory('${parent.path}/$carpeta');
      if (!await newDir.exists()) await newDir.create();
      await f.rename('${newDir.path}/${f.uri.pathSegments.last}');
    }
    Fluttertoast.showToast(msg: "Movidas");
    selected.clear();
    _loadFiles();
  }

  Future<String?> _askFolderName(BuildContext ctx, String title) async {
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

  String _formatDuration(Duration d) {
    String td(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0
        ? "${td(d.inHours)}:${td(d.inMinutes % 60)}:${td(d.inSeconds % 60)}"
        : "${td(d.inMinutes)}:${td(d.inSeconds % 60)}";
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: selected.isEmpty
            ? Text(widget.folder.name)
            : Text('${selected.length} seleccionadas'),
        actions: selected.isEmpty
            ? null
            : [
                IconButton(
                    icon: Icon(Icons.delete), onPressed: _deleteSelected),
                IconButton(
                    icon: Icon(Icons.folder_open), onPressed: _moveSelected),
              ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: files.length,
        itemBuilder: (_, i) {
          final file = files[i];
          final isSel = selected.contains(i);
          return FutureBuilder<Uint8List?>(
            future: file.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
            builder: (_, snap) {
              if (!snap.hasData) return SizedBox.shrink();
              final isVideo = file.type == AssetType.video;
              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    isSel ? selected.remove(i) : selected.add(i);
                  });
                },
                onTap: () {
                  if (selected.isNotEmpty) {
                    setState(() {
                      isSel ? selected.remove(i) : selected.add(i);
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewerScreen(files: files, index: i),
                      ),
                    );
                  }
                },
                child: Stack(fit: StackFit.expand, children: [
                  ExtendedImage.memory(snap.data!,
                      fit: BoxFit.cover, cacheRawData: true),
                  if (isVideo)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_outline,
                              color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(_formatDuration(file.videoDuration),
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _toggleFavorite(file),
                      child: Icon(
                        favorites.contains(file.id)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.yellowAccent,
                      ),
                    ),
                  ),
                  if (isSel)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Icon(Icons.check_circle, color: Colors.blueAccent),
                    ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> files;
  final int index;
  ViewerScreen({required this.files, required this.index});

  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late PageController _pageController;
  int current = 0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    current = widget.index;
    _pageController = PageController(initialPage: current);
    _prepareVideo();
  }

  void _prepareVideo() async {
    _videoController?.dispose();
    final file = await widget.files[current].file;
    if (widget.files[current].type == AssetType.video && file != null) {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.play();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (i) {
          setState(() => current = i);
          _prepareVideo();
        },
        itemBuilder: (_, i) {
          final f = widget.files[i];
          if (f.type == AssetType.image || f.type == AssetType.audio) {
            return FutureBuilder<File?>(
              future: f.file,
              builder: (_, snap) {
                if (!snap.hasData)
                  return Center(child: CircularProgressIndicator());
                return Center(
                    child: ExtendedImage.file(snap.data!, fit: BoxFit.contain));
              },
            );
          } else if (f.type == AssetType.video) {
            return _videoController != null &&
                    _videoController!.value.isInitialized
                ? Center(
                    child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!)),
                  )
                : Center(child: CircularProgressIndicator());
          } else {
            return Center(child: Text("Formato no soportado"));
          }
        },
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<AssetEntity> favFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFavs();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Favoritos')),
      body: favFiles.isEmpty
          ? Center(child: Text('No hay favoritos'))
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
              itemCount: favFiles.length,
              itemBuilder: (_, i) {
                final file = favFiles[i];
                return FutureBuilder<Uint8List?>(
                  future:
                      file.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
                  builder: (_, snap) {
                    if (!snap.hasData) return SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ViewerScreen(files: favFiles, index: i)),
                        );
                      },
                      child: ExtendedImage.memory(snap.data!,
                          fit: BoxFit.cover, cacheRawData: true),
                    );
                  },
                );
              },
            ),
    );
  }
}
