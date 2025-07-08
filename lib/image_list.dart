import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';

class ImageListScreen extends StatefulWidget {
  final Directory folder;
  const ImageListScreen({required this.folder, Key? key}) : super(key: key);

  @override
  State<ImageListScreen> createState() => _ImageListScreenState();
}

enum FiltroTipo { diaMesAno, mesAno, ano, peso }

class _ImageListScreenState extends State<ImageListScreen> {
  bool isGridView = true;
  bool ascending = false;
  bool selectionMode = false;
  FiltroTipo filtroSeleccionado = FiltroTipo.diaMesAno;
  List<File> mediaFiles = [];
  Set<File> selectedFiles = {};
  Map<String, List<File>> groupedFiles = {};

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _loadFiles();
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
      await Permission.storage.request();
    }
  }

  void _loadFiles() async {
    final files = await compute<List<String>, List<File>>(
      _loadMediaFilesInBackground,
      widget.folder.listSync().map((f) => f.path).toList(),
    );
    setState(() => mediaFiles = files);
  }

  static List<File> _loadMediaFilesInBackground(List<String> paths) {
    return paths
        .where((path) => _isMedia(path))
        .map((path) => File(path))
        .toList();
  }

  static bool _isMedia(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv');
  }

  static bool _isVideo(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv');
  }

  Future<ImageProvider> _getThumbnail(File file) async {
    if (_isVideo(file.path)) {
      final thumb = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 70,
      );
      return MemoryImage(thumb ?? Uint8List(0));
    } else {
      return FileImage(file);
    }
  }

  void _showFiltroDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Filtrar por'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filtroOption(FiltroTipo.diaMesAno, "Día-Mes-Año"),
              _filtroOption(FiltroTipo.mesAno, "Mes-Año"),
              _filtroOption(FiltroTipo.ano, "Años"),
              _filtroOption(FiltroTipo.peso, "Peso"),
            ],
          ),
        );
      },
    );
  }

  Widget _filtroOption(FiltroTipo tipo, String label) {
    return RadioListTile<FiltroTipo>(
      title: Text(label),
      value: tipo,
      groupValue: filtroSeleccionado,
      onChanged: (value) {
        if (value != null) {
          setState(() => filtroSeleccionado = value);
          Navigator.of(context).pop();
        }
      },
    );
  }

  List<File> _applySorting(List<File> files) {
    files.sort((a, b) {
      if (filtroSeleccionado == FiltroTipo.peso) {
        return ascending
            ? a.lengthSync().compareTo(b.lengthSync())
            : b.lengthSync().compareTo(a.lengthSync());
      } else {
        return ascending
            ? a.lastModifiedSync().compareTo(b.lastModifiedSync())
            : b.lastModifiedSync().compareTo(a.lastModifiedSync());
      }
    });
    return files;
  }

  Map<String, List<File>> _groupFiles(List<File> files) {
    final Map<String, List<File>> grouped = {};
    for (var file in files) {
      final date = file.lastModifiedSync();
      late String key;
      switch (filtroSeleccionado) {
        case FiltroTipo.diaMesAno:
          key = DateFormat('yyyy-MM-dd').format(date);
          break;
        case FiltroTipo.mesAno:
          key = DateFormat('yyyy-MM').format(date);
          break;
        case FiltroTipo.ano:
          key = DateFormat('yyyy').format(date);
          break;
        case FiltroTipo.peso:
          key = 'Todos';
          break;
      }
      grouped.putIfAbsent(key, () => []).add(file);
    }
    return grouped;
  }

  void _toggleSelection(File file) {
    setState(() {
      if (selectedFiles.contains(file)) {
        selectedFiles.remove(file);
      } else {
        selectedFiles.add(file);
      }
    });
  }

  void _deleteSelected() async {
    for (var file in selectedFiles) {
      await file.delete();
    }
    selectedFiles.clear();
    _loadFiles();
  }

  void _moveSelected() async {
    final newPath = await _selectDestinationFolder();
    if (newPath != null) {
      for (var file in selectedFiles) {
        final newFile = File('$newPath/${p.basename(file.path)}');
        await file.rename(newFile.path);
      }
      selectedFiles.clear();
      _loadFiles();
    }
  }

  Future<String?> _selectDestinationFolder() async {
    final root = Directory('/storage/emulated/0/NebulaVault');
    final allDirs =
        root.listSync(recursive: true).whereType<Directory>().toList();

    String search = '';

    return await showDialog<String>(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState) {
          final filtered = allDirs
              .where((dir) => p
                  .basename(dir.path)
                  .toLowerCase()
                  .contains(search.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('Mover a...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => setState(() => search = value),
                  decoration: const InputDecoration(hintText: 'Buscar carpeta'),
                ),
                SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, index) {
                      final dir = filtered[index];
                      return ListTile(
                        title: Text(p.basename(dir.path)),
                        onTap: () {
                          Navigator.of(context).pop(dir.path);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      selectionMode = !selectionMode;
      if (!selectionMode) selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedFiles = _applySorting([...mediaFiles]);
    groupedFiles = _groupFiles(sortedFiles);

    return Scaffold(
      appBar: AppBar(
        title: selectionMode
            ? Text("${selectedFiles.length} seleccionadas")
            : Text(widget.folder.path.split('/').last),
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedFiles.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              onPressed: selectedFiles.isEmpty ? null : _moveSelected,
            ),
          ],
          IconButton(
            icon: Icon(selectionMode ? Icons.close : Icons.check_box),
            onPressed: _toggleSelectionMode,
          ),
          if (!selectionMode) ...[
            IconButton(
              icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () => setState(() => ascending = !ascending),
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _showFiltroDialog,
            ),
            IconButton(
              icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => isGridView = !isGridView),
            ),
          ],
        ],
      ),
      body: CustomScrollView(
        slivers: groupedFiles.entries.map((entry) {
          final groupLabel = entry.key;
          final files = entry.value;

          return SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  groupLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              isGridView ? _buildGridSection(files) : _buildListSection(files),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGridSection(List<File> files) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: files.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemBuilder: (_, index) {
          final file = files[index];
          final isSelected = selectedFiles.contains(file);

          return FutureBuilder(
            future: _getThumbnail(file),
            builder: (_, snapshot) {
              if (!snapshot.hasData) return Container(color: Colors.grey[300]);
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (selectionMode) return;

                      final List<File> filterlist =
                          groupedFiles.entries.expand((e) => e.value).toList();

                      final int i = filterlist.indexOf(file);

                      showDialog(
                        context: context,
                        builder: (_) => FullImageView(
                            allFiles: filterlist, initialIndex: i),
                      );
                    },
                    child: Opacity(
                      opacity: isSelected ? 0.5 : 1.0,
                      child: Image(
                        image: snapshot.data as ImageProvider,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                  if (_isVideo(file.path))
                    const Positioned(
                      bottom: 8,
                      right: 8,
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 24),
                    ),
                  if (selectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ Botón de pantalla completa

                          // ✅ Botón de selección
                          GestureDetector(
                            onTap: () => _toggleSelection(file),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: Colors.white,
                            ),
                          ),

                          GestureDetector(
                            onTap: () {
                              final List<File> filterlist = groupedFiles.entries
                                  .expand((e) => e.value)
                                  .toList();

                              final int i = filterlist.indexOf(file);

                              showDialog(
                                context: context,
                                builder: (_) => FullImageView(
                                    allFiles: filterlist, initialIndex: i),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildListSection(List<File> files) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      itemBuilder: (_, index) {
        final file = files[index];
        final sizeMB = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
        final date =
            DateFormat('dd/MM/yyyy – HH:mm').format(file.lastModifiedSync());
        final isSelected = selectedFiles.contains(file);

        return ListTile(
          leading: FutureBuilder(
            future: _getThumbnail(file),
            builder: (_, snapshot) {
              if (!snapshot.hasData)
                return const SizedBox(width: 60, height: 60);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isSelected ? 0.5 : 1.0,
                    child: Image(
                      image: snapshot.data as ImageProvider,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isVideo(file.path))
                    const Icon(Icons.play_circle_fill,
                        color: Colors.white70, size: 24),
                ],
              );
            },
          ),
          title: Text('$sizeMB MB'),
          subtitle: Text('Creado el: $date'),
          trailing: selectionMode
              ? GestureDetector(
                  onDoubleTap: () {
                    final List<File> filterlist =
                        groupedFiles.entries.expand((e) => e.value).toList();

                    final int i = filterlist.indexOf(file);

                    showDialog(
                      context: context,
                      builder: (_) =>
                          FullImageView(allFiles: filterlist, initialIndex: i),
                    );
                  },
                  onTap: () => _toggleSelection(file),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: Colors.blue,
                  ),
                )
              : null,
          onTap: () {
            final List<File> filterlist =
                groupedFiles.entries.expand((e) => e.value).toList();

            final int i = filterlist.indexOf(file);

            if (!selectionMode) {
              showDialog(
                  context: context,
                  builder: (_) =>
                      FullImageView(allFiles: filterlist, initialIndex: i));
            }
          },
        );
      },
    );
  }
}

class FullImageView extends StatefulWidget {
  final List<File> allFiles;
  final int initialIndex;

  FullImageView({
    required List<File> allFiles,
    required this.initialIndex,
  }) : allFiles = allFiles.toList();

  @override
  _FullImageViewState createState() => _FullImageViewState();
}

class _FullImageViewState extends State<FullImageView> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  Timer? _videoUpdateTimer;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadVideoIfNeeded(widget.allFiles[_currentIndex]);
  }

  bool _isVideo(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
  }

  void _loadVideoIfNeeded(File file) async {
    if (_isVideo(file.path)) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.play();
      _startVideoTimer();
      setState(() {});
    } else {
      _videoController?.dispose();
      _videoController = null;
      _stopVideoTimer();
    }
  }

  void _startVideoTimer() {
    _videoUpdateTimer?.cancel();
    _videoUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted &&
          _videoController != null &&
          _videoController!.value.isInitialized) {
        setState(() {});
      }
    });
  }

  void _stopVideoTimer() {
    _videoUpdateTimer?.cancel();
    _videoUpdateTimer = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = widget.allFiles[_currentIndex];
    final isVideo = _isVideo(currentFile.path);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.allFiles.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _loadVideoIfNeeded(widget.allFiles[index]);
              },
              itemBuilder: (context, index) {
                final file = widget.allFiles[index];
                final isVideo = _isVideo(file.path);

                if (isVideo &&
                    _videoController != null &&
                    _videoController!.value.isInitialized &&
                    index == _currentIndex) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                } else {
                  return PhotoViewGallery.builder(
                    pageController: PageController(initialPage: index),
                    itemCount: 1,
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                    builder: (context, _) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: FileImage(file),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3.0,
                        heroAttributes: PhotoViewHeroAttributes(tag: file.path),
                      );
                    },
                  );
                }
              },
            ),
            if (_showControls)
              Positioned(
                top: 40,
                left: 20,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            if (isVideo &&
                _videoController != null &&
                _videoController!.value.isInitialized &&
                _showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDuration(_videoController!.value.position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Expanded(
                            child: Slider(
                              value: _videoController!.value.position.inSeconds
                                  .toDouble(),
                              min: 0,
                              max: _videoController!.value.duration.inSeconds
                                  .toDouble(),
                              onChanged: (value) {
                                _videoController!
                                    .seekTo(Duration(seconds: value.toInt()));
                              },
                            ),
                          ),
                          Text(
                            _formatDuration(_videoController!.value.duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.replay_5, color: Colors.white),
                            onPressed: () {
                              final newPosition =
                                  _videoController!.value.position -
                                      const Duration(seconds: 5);
                              _videoController!.seekTo(
                                  newPosition > Duration.zero
                                      ? newPosition
                                      : Duration.zero);
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _videoController!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() {
                                _videoController!.value.isPlaying
                                    ? _videoController!.pause()
                                    : _videoController!.play();
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_5,
                                color: Colors.white),
                            onPressed: () {
                              final newPosition =
                                  _videoController!.value.position +
                                      const Duration(seconds: 5);
                              if (newPosition <
                                  _videoController!.value.duration) {
                                _videoController!.seekTo(newPosition);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _videoUpdateTimer?.cancel();
    super.dispose();
  }
}
