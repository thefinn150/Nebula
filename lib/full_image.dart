import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

class FullImageView extends StatefulWidget {
  final List<File> allImages;
  final int initialIndex;

  FullImageView({
    required List<File> allImages,
    required this.initialIndex,
  }) : allImages = allImages.reversed.toList();

  @override
  _FullImageViewState createState() => _FullImageViewState();
}

class _FullImageViewState extends State<FullImageView> {
  late PageController _pageController;
  late int paginacion;
  VideoPlayerController? _videoController;
  Timer? _videoUpdateTimer;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    paginacion = widget.initialIndex;
    _pageController = PageController(initialPage: paginacion);
    _loadVideoIfNeeded(widget.allImages[paginacion]);
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
    final currentFile = widget.allImages[paginacion];
    final isVideo = _isVideo(currentFile.path);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.allImages.length,
              onPageChanged: (index) {
                setState(() {
                  paginacion = index;
                });
                _loadVideoIfNeeded(widget.allImages[index]);
              },
              itemBuilder: (context, index) {
                final file = widget.allImages[index];
                final isVideo = _isVideo(file.path);

                if (isVideo &&
                    _videoController != null &&
                    _videoController!.value.isInitialized) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                } else {
                  return Center(
                    child: PhotoView(
                      imageProvider: FileImage(file),
                      backgroundDecoration:
                          const BoxDecoration(color: Colors.black),
                    ),
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

            // Video Controls Overlay
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
