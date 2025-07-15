import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/viewer.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:extended_image/extended_image.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

class FileListScreen extends StatefulWidget {
  final Directory folder;
  final List<Directory> allFolders;
  FileListScreen({required this.folder, required this.allFolders});
  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<AssetEntity> files = [];
  Map<String, List<AssetEntity>> grouped = {};
  List<AssetEntity> displayed = [];
  List<dynamic> selected = [];
  String filterType = 'all';
  ScrollController sc = ScrollController();
  bool isSelecting = false;
  String? _currentDate;
  bool _showFloatingDate = false;
  Timer? _floatingDateTimer;
  bool sortByDuration = false;
  bool orderByDuration = false;
  Map<String, Duration> videoDurations = {};
  List<File> flatFiles = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
    sc.addListener(() {
      _updateFloatingDate();
    });
  }

  void _updateFloatingDate() {
    double offset = sc.offset;
    double accHeight = 0;

    final isFlat = !widget.folder.path.contains('NebulaVault');

    if (isFlat) {
      final sortedEntries = groupedFlatFiles.entries.toList()
        ..sort((a, b) {
          final dateA = DateFormat('dd-MM-yyyy').parse(a.key);
          final dateB = DateFormat('dd-MM-yyyy').parse(b.key);
          return dateB.compareTo(dateA);
        });

      for (var entry in sortedEntries) {
        accHeight += 48; // altura título grupo
        final rowCount = (entry.value.length / 3.0).ceil();
        accHeight += rowCount * 120;

        if (offset < accHeight) {
          if (_currentDate != entry.key) {
            setState(() {
              _currentDate = entry.key;
              _showFloatingDate = true;
            });

            _floatingDateTimer?.cancel();
            _floatingDateTimer = Timer(const Duration(seconds: 2), () {
              setState(() {
                _showFloatingDate = false;
              });
            });
          }
          break;
        }
      }
    } else {
      // código que ya tienes para AssetEntity
      final sortedEntries = grouped.entries.toList()
        ..sort((a, b) {
          final dateA = DateFormat('dd-MM-yyyy').parse(a.key);
          final dateB = DateFormat('dd-MM-yyyy').parse(b.key);
          return dateB.compareTo(dateA);
        });

      for (var entry in sortedEntries) {
        accHeight += 48; // altura título grupo
        final rowCount = (entry.value.length / 3.0).ceil();
        accHeight += rowCount * 120;

        if (offset < accHeight) {
          if (_currentDate != entry.key) {
            setState(() {
              _currentDate = entry.key;
              _showFloatingDate = true;
            });

            _floatingDateTimer?.cancel();
            _floatingDateTimer = Timer(const Duration(seconds: 2), () {
              setState(() {
                _showFloatingDate = false;
              });
            });
          }
          break;
        }
      }
    }
  }

  Future<void> _loadFiles() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final folderName = widget.folder.path.split('/').last.toLowerCase();
    final isFlatFolder = !widget.folder.path.contains('NebulaVault');

    if (isFlatFolder) {
      // Leer archivos tipo File desde el sistema sin duplicarlos
      flatFiles = await _getMediaFilesFromFileSystem(widget.folder);
      files = [];
      displayed = [];
      grouped.clear();
    } else {
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.all,
        filterOption: FilterOptionGroup(),
      );

      final folderPath = paths.firstWhere(
        (e) => e.name.toLowerCase() == folderName,
        orElse: () => paths.first,
      );

      files = await folderPath.getAssetListPaged(page: 0, size: 1000);
      flatFiles = [];

      // Duraciones de videos
      videoDurations.clear();
      for (final asset in files.where((e) => e.type == AssetType.video)) {
        videoDurations[asset.id] = Duration(seconds: asset.duration);
      }

      // Ordenamiento
      if (filterType == 'video' && orderByDuration) {
        files.sort((a, b) => (videoDurations[b.id] ?? Duration.zero)
            .compareTo(videoDurations[a.id] ?? Duration.zero));
      } else {
        files.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      }

      displayed = files;
      _groupByDate();
    }

    setState(() {});
  }

  Map<String, List<File>> groupedFlatFiles = {};

  void _groupFlatFilesByDate() {
    groupedFlatFiles.clear();
    final fmt = DateFormat('dd-MM-yyyy');

    for (var f in flatFiles) {
      final modified = f.lastModifiedSync();
      final d = fmt.format(modified);
      groupedFlatFiles.putIfAbsent(d, () => []).add(f);
    }
  }

  void _groupByDate() {
    grouped.clear();
    final fmt = DateFormat('dd-MM-yyyy');

    for (var f in files) {
      final d = fmt.format(f.createDateTime);
      grouped.putIfAbsent(d, () => []).add(f);
    }

    displayed = files;
  }

  void _toggleType(String t) => setState(() {
        filterType = t;
        _loadFiles();
      });

  Widget _buildDateGroup(
      String date, List<AssetEntity> items, List<AssetEntity> listForViewer) {
    final allSel = items.every((i) => selected.contains(i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: isSelecting
              ? Checkbox(
                  value: allSel,
                  onChanged: (_) {
                    setState(() {
                      if (allSel) {
                        selected.removeWhere((i) => items.contains(i));
                      } else {
                        selected
                            .addAll(items.where((i) => !selected.contains(i)));
                      }
                    });
                  },
                )
              : null,
          title: Text(
            '$date • ${items.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          cacheExtent: MediaQuery.of(context).size.height * 4,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final asset = items[i];
            final sel = selected.contains(asset);

            return RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: asset
                        .thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ColoredBox(color: Colors.black12);
                      }
                      if (snapshot.data == null || snapshot.data!.isEmpty) {
                        return const ColoredBox(color: Colors.black12);
                      }

                      return ExtendedImage.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        enableMemoryCache: true,
                        clearMemoryCacheWhenDispose: true,
                        loadStateChanged: (state) {
                          if (state.extendedImageLoadState ==
                              LoadState.failed) {
                            return const ColoredBox(color: Colors.black12);
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  // Duración + ícono si es video
                  if (asset.type == AssetType.video)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      right: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.videocam,
                              color: Colors.white, size: 16),
                          Text(
                            _formatDuration(asset.videoDuration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              shadows: [
                                Shadow(blurRadius: 2, color: Colors.black)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Selección visual
                  if (sel)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: const Icon(Icons.check_circle,
                          color: Colors.lightGreen),
                    ),
                  Positioned.fill(
                    child: isSelecting
                        ? GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onLongPress: () {
                              if (!selected.contains(asset)) {
                                setState(() {
                                  selected.add(asset);
                                });
                              }
                            },
                            //No
                            onTap: () {
                              print('1111111111111111111111111111');
                              setState(() {
                                if (sel) {
                                  selected.remove(asset);
                                } else {
                                  selected.add(asset);
                                }
                              });
                            },
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              print('222222222222222222222222222222222222');
                              final indexInViewer =
                                  listForViewer.indexOf(asset);
                              if (indexInViewer != -1) {
                                _openViewer(listForViewer, indexInViewer);
                              }
                            },
                            onLongPress: () {
                              if (!selected.contains(asset)) {
                                setState(() {
                                  selected.add(asset);
                                  isSelecting = true;
                                });
                              }
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openFileViewer(List<File> list, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          files: list,
          startIndex: index,
          folder: widget.folder,
        ),
      ),
    );
  }

  void _openViewer(List<AssetEntity> list, int index) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            files: list,
            startIndex: index,
            folder: widget.folder,
          ),
        ),
      );

  @override
  Widget build(BuildContext ctx) {
    final usingFlat = !widget.folder.path.contains('NebulaVault');
    final currentFiles = usingFlat ? flatFiles : files;

    final images = currentFiles.where((f) {
      final name = f is AssetEntity
          ? f.title?.toLowerCase() ?? ''
          : (f as File).path.split('/').last.toLowerCase();
      return name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png') ||
          name.endsWith('.webp');
    }).toList();

    final videos = currentFiles.where((f) {
      final name = f is AssetEntity
          ? f.title?.toLowerCase() ?? ''
          : (f as File).path.split('/').last.toLowerCase();
      return name.endsWith('.mp4') || name.endsWith('.mov');
    }).toList();

    final gifs = currentFiles.where((f) {
      final name = f is AssetEntity
          ? f.title?.toLowerCase() ?? ''
          : (f as File).path.split('/').last.toLowerCase();
      return name.endsWith('.gif');
    }).toList();

    final tabs = <Map<String, dynamic>>[];

    if (images.isNotEmpty) {
      tabs.add({
        'label': 'Imágenes (${images.length})',
        'type': 'image',
        'items': images
      });
    }
    if (videos.isNotEmpty) {
      tabs.add({
        'label': 'Videos (${videos.length})',
        'type': 'video',
        'items': videos
      });
    }
    if (gifs.isNotEmpty) {
      tabs.add(
          {'label': 'GIFs (${gifs.length})', 'type': 'gif', 'items': gifs});
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.folder.path.split('/').last),
          bottom: tabs.length > 1
              ? TabBar(
                  isScrollable: true,
                  tabs: tabs.map((t) => Tab(text: t['label'])).toList(),
                )
              : null,
          actions: [
            if (!isSelecting)
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Seleccionar',
                onPressed: () => setState(() => isSelecting = true),
              ),
            if (isSelecting)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar',
                onPressed: () => setState(() {
                  selected.clear();
                  isSelecting = false;
                }),
              ),
            if (selected.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.move_to_inbox),
                onPressed: _moveSelected,
                tooltip: 'Mover',
              ),
            if (selected.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelected,
                tooltip: 'Eliminar',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'fecha') {
                  setState(() {
                    orderByDuration = false;
                    files.sort(
                        (a, b) => b.createDateTime.compareTo(a.createDateTime));
                    displayed = files;
                    _groupByDate();
                  });
                } else if (value == 'duracion') {
                  setState(() {
                    orderByDuration = true;
                  });

                  // Ordenar por duración inmediatamente, si ya cargaron
                  setState(() {
                    files = files
                        .where((f) => f.type == AssetType.video)
                        .toList()
                      ..sort((a, b) => b.duration.compareTo(a.duration));
                    displayed = files;
                    grouped.clear();
                  });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'fecha',
                  child: Text('Ordenar por fecha'),
                ),
                const PopupMenuItem(
                  value: 'duracion',
                  child: Text('Ordenar por duración'),
                ),
              ],
              icon: const Icon(Icons.sort),
            ),
          ],
        ),
        body: TabBarView(
          children: tabs.map((t) {
            final usingFlat = !widget.folder.path.contains('NebulaVault');
            final type = t['type'];

            if (usingFlat) {
              final flatFiltered = flatFiles.where((f) {
                final path = f.path.toLowerCase();
                if (type == 'image')
                  return path.endsWith('.jpg') ||
                      path.endsWith('.jpeg') ||
                      path.endsWith('.png') ||
                      path.endsWith('.webp');
                if (type == 'video')
                  return path.endsWith('.mp4') || path.endsWith('.mov');
                if (type == 'gif') return path.endsWith('.gif');
                return false;
              }).toList();

              // Agrupa
              groupedFlatFiles.clear();
              final fmt = DateFormat('dd-MM-yyyy');
              for (var f in flatFiltered) {
                final modified = f.lastModifiedSync();
                final d = fmt.format(modified);
                groupedFlatFiles.putIfAbsent(d, () => []).add(f);
              }

              final sortedEntries = groupedFlatFiles.entries.toList()
                ..sort((a, b) {
                  final dateA = DateFormat('dd-MM-yyyy').parse(a.key);
                  final dateB = DateFormat('dd-MM-yyyy').parse(b.key);
                  return dateB.compareTo(dateA);
                });

              return Stack(
                children: [
                  Scrollbar(
                    controller: sc,
                    thickness: 20,
                    radius: const Radius.circular(10),
                    child: ListView(
                      controller: sc,
                      children: sortedEntries
                          .map((e) => _buildFlatDateGroup(e.key, e.value))
                          .toList(),
                    ),
                  ),
                  if (_showFloatingDate && _currentDate != null)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ],
                        ),
                        child: Text(
                          _currentDate!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                    )
                ],
              );
            }

            // Si es AssetEntity, se sigue usando tu lógica original
            List<AssetEntity> typeFiles = t['items'] as List<AssetEntity>;

            if (type == 'video' && orderByDuration) {
              typeFiles = List<AssetEntity>.from(typeFiles)
                ..sort((a, b) => b.duration.compareTo(a.duration));
            }

            if (type == 'video' && orderByDuration) {
              return ListView(
                controller: sc,
                children: [
                  _buildDateGroup(
                    'Videos ordenados por duración',
                    typeFiles,
                    typeFiles,
                  )
                ],
              );
            }

            grouped.clear();
            final fmt = DateFormat('dd-MM-yyyy');
            for (var f in typeFiles) {
              final d = fmt.format(f.createDateTime);
              grouped.putIfAbsent(d, () => []).add(f);
            }

            final sortedEntries = grouped.entries.toList()
              ..sort((a, b) {
                final dateA = DateFormat('dd-MM-yyyy').parse(a.key);
                final dateB = DateFormat('dd-MM-yyyy').parse(b.key);
                return dateB.compareTo(dateA);
              });

            return Stack(
              children: [
                Scrollbar(
                  controller: sc,
                  thickness: 20,
                  radius: const Radius.circular(10),
                  child: ListView(
                    controller: sc,
                    children: sortedEntries
                        .map((e) => _buildDateGroup(e.key, e.value, typeFiles))
                        .toList(),
                  ),
                ),
                if (_showFloatingDate && _currentDate != null)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: Text(
                        _currentDate!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFlatDateGroup(String date, List<File> items) {
    final allSel = items.every((i) => selected.contains(i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: isSelecting
              ? Checkbox(
                  value: allSel,
                  onChanged: (_) {
                    setState(() {
                      if (allSel) {
                        selected.removeWhere((i) => items.contains(i));
                      } else {
                        selected
                            .addAll(items.where((i) => !selected.contains(i)));
                      }
                    });
                  },
                )
              : null,
          title: Text(
            '$date • ${items.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          cacheExtent: MediaQuery.of(context).size.height * 4,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final file = items[i];
            final isVideo = file.path.toLowerCase().endsWith('.mp4') ||
                file.path.toLowerCase().endsWith('.mov');
            final sel = selected.contains(file);

            return Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  FutureBuilder<Uint8List?>(
                    future: _generateVideoThumbnail(file),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const ColoredBox(color: Colors.black12);
                      }
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: Colors.black12),
                      );
                    },
                  )
                else
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: Colors.black12),
                  ),
                if (isVideo)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    right: 4,
                    child: FutureBuilder<Duration>(
                      future: _getVideoDuration(file),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.videocam,
                                color: Colors.white, size: 16),
                            Text(
                              _formatDuration(snap.data!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                shadows: [
                                  Shadow(blurRadius: 2, color: Colors.black)
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (sel)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_circle,
                        color: Colors.lightGreen),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () {
                      if (!selected.contains(file)) {
                        setState(() => selected.add(file));
                      }
                    },
                    onTap: () {
                      print('333333333333333333333333333333333333333');
                      setState(() {
                        if (isSelecting) {
                          setState(() {
                            if (sel) {
                              selected.remove(file);
                            } else {
                              selected.add(file);
                            }
                          });
                        } else {
                          _openFileViewer(items, i);
                        }
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFlatGrid(List<File> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final file = items[i];
        final isVideo = file.path.toLowerCase().endsWith('.mp4') ||
            file.path.toLowerCase().endsWith('.mov');
        final isSelected = selected.contains(file);

        return GestureDetector(
          onTap: () {
            print('4444444444444444444444444444444444444');
            if (isSelecting) {
              setState(() {
                if (isSelected) {
                  selected.remove(file);
                } else {
                  selected.add(file);
                }
              });
            } else {
              _openFileViewer(items, i);
            }
          },
          onLongPress: () {
            setState(() {
              isSelecting = true;
              if (!selected.contains(file)) selected.add(file);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo)
                FutureBuilder<Uint8List?>(
                  future: _generateVideoThumbnail(file),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done ||
                        snapshot.data == null) {
                      return const ColoredBox(color: Colors.black12);
                    }

                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: Colors.black12),
                    );
                  },
                )
              else
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Colors.black12),
                ),

              // Ícono de duración si es video
              if (isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white, size: 16),
                      FutureBuilder<Duration>(
                        future: _getVideoDuration(file),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return Text(
                            _formatDuration(snap.data!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              shadows: [
                                Shadow(blurRadius: 2, color: Colors.black)
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              // Visual de selección
              if (isSelecting && isSelected)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child:
                      const Icon(Icons.check_circle, color: Colors.lightGreen),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Duration> _getVideoDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration;
    await controller.dispose();
    return duration;
  }

  Future<void> _moveSelected() async {
    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar movimiento'),
        content: Text(
            '¿Estás seguro de que deseas mover ${selected.length} archivo(s)?'),
        actions: [
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context, false)),
          ElevatedButton(
              child: const Text('Mover'),
              onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm != true) return;

    final target = await showDialog<Directory>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        final all = widget.allFolders;
        var fit = all;
        return StatefulBuilder(builder: (_, st) {
          return AlertDialog(
            title: const Text('Mover a...'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: 'Buscar carpeta'),
                onChanged: (q) => st(() => fit = all
                    .where((d) => d.path
                        .split('/')
                        .last
                        .toLowerCase()
                        .contains(q.toLowerCase()))
                    .toList()),
              ),
              SizedBox(
                height: 200,
                width: 300,
                child: ListView(
                  children: fit
                      .map((f) => ListTile(
                            title: Text(f.path.split('/').last),
                            onTap: () => Navigator.pop(context, f),
                          ))
                      .toList(),
                ),
              )
            ]),
          );
        });
      },
    );

    if (target == null) return;

    int movedCount = 0;

    for (var item in selected) {
      try {
        File? fileToMove;

        if (item is File) {
          fileToMove = item;
        } else if (item is AssetEntity) {
          fileToMove = await item.file;
        }

        if (fileToMove == null) continue;

        final name = fileToMove.path.split('/').last;
        final newPath = '${target.path}/$name';
        final newFile = File(newPath);

        await fileToMove.copy(newFile.path);

        if (await newFile.exists()) {
          await fileToMove.delete();

          // Si es AssetEntity, elimina también de galería
          if (item is AssetEntity) {
            await PhotoManager.editor.deleteWithIds([item.id]);
          }

          movedCount++;
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error al mover archivo: $e');
      }
    }

    Fluttertoast.showToast(msg: 'Movidos $movedCount archivo(s)');

    setState(() {
      selected.clear();
      isSelecting = false;
    });

    await _loadFilesForFolder(widget.folder);
  }

  Future<Uint8List?> _generateVideoThumbnail(File file) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400, // puedes ajustar el tamaño
        quality: 75,
      );
      return bytes;
    } catch (e) {
      return null;
    }
  }

  Future<List<File>> _getMediaFilesFromFileSystem(Directory folder) async {
    final mediaExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.mp4',
      '.mov',
      '.webp'
    ];
    List<File> found = [];

    try {
      final contents = await folder.list(recursive: false).toList();
      for (var entity in contents) {
        if (entity is File &&
            mediaExtensions
                .any((ext) => entity.path.toLowerCase().endsWith(ext))) {
          found.add(entity);
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error leyendo carpeta: $e');
    }

    return found;
  }

  Future<void> _loadFilesForFolder(Directory folder) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final folderName = folder.path.split('/').last.toLowerCase();
    final isFlatFolder = !folder.path.contains('NebulaVault');

    if (isFlatFolder) {
      // Leer archivos directamente sin duplicarlos ni convertir a AssetEntity
      flatFiles = await _getMediaFilesFromFileSystem(folder);
      files = []; // vaciar AssetEntity lista para evitar conflictos

      setState(() {
        // Aquí puedes mostrar flatFiles usando FileImage en el builder
        // Limpia agrupados porque no usas AssetEntity
        grouped.clear();
      });
    } else {
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.all,
        filterOption: FilterOptionGroup(),
      );
      final match = paths.firstWhere(
        (e) => e.name.toLowerCase() == folderName,
        orElse: () => paths.first,
      );
      files = await match.getAssetListPaged(page: 0, size: 1000);

      setState(() {
        files.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        displayed = files;
        _groupByDate();
        flatFiles.clear();
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
            '¿Estás seguro de que deseas eliminar ${selected.length} archivo(s)? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (var asset in selected) {
      try {
        final file = await asset.file;
        if (file != null && await file.exists()) {
          await file.delete();
        }

        // Eliminar de la galería
        await PhotoManager.editor.deleteWithIds([asset.id]);
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error al eliminar archivo: $e');
      }
    }

    Fluttertoast.showToast(msg: 'Eliminados ${selected.length} archivo(s)');
    setState(() {
      selected.clear();
      isSelecting = false;
      _loadFiles();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
