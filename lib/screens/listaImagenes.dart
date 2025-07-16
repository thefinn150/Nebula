import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/pantallaCompleta.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';

class FileListScreen extends StatefulWidget {
  final AssetPathEntity folder;
  FileListScreen({required this.folder});

  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<AssetEntity> files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final f = await widget.folder.getAssetListPaged(page: 0, size: 10000);
    setState(() {
      files = f;
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
    } else {
      return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: files.length,
        itemBuilder: (_, i) {
          final file = files[i];
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewerScreen(files: files, index: i),
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
                            _formatDuration(
                                file.videoDuration), // 🛠️ Corrección 3
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
      ),
    );
  }
}
