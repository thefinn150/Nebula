import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/show-file-details.dart';

class ViewerScreen extends StatelessWidget {
  final List<AssetEntity> files;
  final int startIndex;
  final Directory folder;
  ViewerScreen(
      {required this.files, required this.startIndex, required this.folder});
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: PageView.builder(
        itemCount: files.length,
        controller: PageController(initialPage: startIndex),
        itemBuilder: (_, i) {
          final f = files[i];
          if (f.type == AssetType.video) return VideoPlayerView(asset: f);
          return ImageViewerView(
              asset: f,
              onDelete: () async {
                final file = await f.file;
                await file?.delete();
                Navigator.pop(c);
              });
        },
      ),
    );
  }
}

class ImageViewerView extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onDelete;
  ImageViewerView({required this.asset, required this.onDelete});
  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder<File?>(
      future: asset.file,
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final file = snap.data!;
        return Stack(children: [
          PhotoView(imageProvider: FileImage(file)),
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                const SizedBox(width: 10),
                ElevatedButton.icon(
                    icon: const Icon(Icons.info),
                    label: const Text('Detalles'),
                    onPressed: () {
                      showFileDetailsDialog(ctx, file);
                    })
              ],
            ),
          )
        ]);
      },
    );
  }
}

class VideoPlayerView extends StatefulWidget {
  final AssetEntity asset;
  VideoPlayerView({required this.asset});
  @override
  _VideoPlayerViewState createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  ChewieController? chewieCtr;
  VideoPlayerController? videoCtr;

  @override
  void initState() {
    super.initState();
    widget.asset.file.then((f) {
      if (f != null) {
        videoCtr = VideoPlayerController.file(f);
        videoCtr!.initialize().then((_) {
          chewieCtr = ChewieController(
              videoPlayerController: videoCtr!,
              autoPlay: true,
              showControls: true,
              allowedScreenSleep: false,
              looping: true,
              zoomAndPan: true);
          setState(() {});
        });
      }
    });
  }

  @override
  void dispose() {
    chewieCtr?.dispose();
    videoCtr?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    if (chewieCtr == null)
      return const Center(child: CircularProgressIndicator());
    return Chewie(controller: chewieCtr!);
  }
}
