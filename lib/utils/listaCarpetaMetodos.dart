import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:convert';

Future<Map<String, String>> loadFolderThumbnails() async {
  final prefs = await SharedPreferences.getInstance();
  final rawData = prefs.getString('folder_thumbnails');
  if (rawData != null) {
    try {
      final List<dynamic> list = jsonDecode(rawData);
      return {
        for (var entry in list) entry['carpeta']: entry['fotoId'],
      };
    } catch (e) {
      return {};
    }
  } else {
    return {};
  }
}

Future<Set<String>> loadFavorites() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('favorites')?.toSet() ?? {};
}

Future<List<AssetEntity>> loadFavs() async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('favorites') ?? [];
  final futures = ids.map((id) => AssetEntity.fromId(id));
  final results = await Future.wait(futures);
  return results.whereType<AssetEntity>().toList();
}

Future<Map<String, int>> countAssetsByType(AssetPathEntity folder) async {
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

String formatDuration(Duration? duration) {
  if (duration == null) return "";
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  return hours > 0 ? "$hours:$minutes:$seconds" : "$minutes:$seconds";
}

Future<Uint8List?> getSafeThumbnail(AssetEntity asset) async {
  try {
    return await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
  } catch (e) {
    return null;
  }
}
