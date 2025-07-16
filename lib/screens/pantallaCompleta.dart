import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ViewerScreen extends StatefulWidget {
  final List<AssetEntity> files;
  final int index;

  ViewerScreen({required this.files, required this.index});

  @override
  _ViewerScreenState createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late ExtendedPageController _pageController;
  int current = 0;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    current = widget.index;
    _pageController = ExtendedPageController(initialPage: current);
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    _videoController?.dispose();
    _chewieController?.dispose();

    final file = await widget.files[current].file;
    if (widget.files[current].type == AssetType.video && file != null) {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white70,
        ),
        additionalOptions: (context) => <OptionItem>[],
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );

      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: ExtendedImageGesturePageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: (i) async {
          setState(() => current = i);
          await _prepareVideo();
        },
        itemBuilder: (_, i) {
          final file = widget.files[i];

          if (file.type == AssetType.image || file.type == AssetType.audio) {
            return FutureBuilder<File?>(
              future: file.file,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ExtendedImage.file(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  mode: ExtendedImageMode.gesture,
                  enableSlideOutPage: false,
                  initGestureConfigHandler: (_) => GestureConfig(
                    minScale: 1.0,
                    maxScale: 4.0,
                    animationMinScale: 0.7,
                    animationMaxScale: 4.5,
                    speed: 1.0,
                    inertialSpeed: 100.0,
                    initialScale: 1.0,
                    inPageView: true,
                    initialAlignment: InitialAlignment.center,
                    cacheGesture: false,
                  ),
                );
              },
            );
          } else if (file.type == AssetType.video) {
            return _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? Center(child: Chewie(controller: _chewieController!))
                : const Center(child: CircularProgressIndicator());
          } else {
            return const Center(child: Text("Formato no soportado"));
          }
        },
      ),
    );
  }
}
