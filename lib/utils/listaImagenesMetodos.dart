import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, List<AssetEntity>> agruparPorFecha(List<AssetEntity> files) {
  final Map<String, List<AssetEntity>> map = {};
  final DateFormat dateFormatter = DateFormat('dd-MM-yyyy');

  for (var file in files) {
    final dateKey = dateFormatter.format(file.modifiedDateTime);
    map.putIfAbsent(dateKey, () => []).add(file);
  }

  // Ordenar cada grupo por hora (más reciente al final, o invierte si quieres)
  for (var entry in map.entries) {
    entry.value
        .sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));
  }

  return map;
}

List<String> obtenerFechasOrdenadas(Map<String, List<AssetEntity>> grouped) {
  final DateFormat formatter = DateFormat('dd-MM-yyyy');
  final keys = grouped.keys.toList();

  keys.sort((a, b) => formatter.parse(b).compareTo(formatter.parse(a)));

  return keys;
}

Future<Set<String>> cargarFavoritos() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('favorites')?.toSet() ?? {};
}

// Dentro de listaImagenesMetodos.dart

class DatosArchivos {
  final List<AssetEntity> todos;
  final List<AssetEntity> imagenes;
  final List<AssetEntity> gifs;
  final List<AssetEntity> videos;

  final Map<String, List<AssetEntity>> groupedImages;
  final Map<String, List<AssetEntity>> groupedGifs;
  final Map<String, List<AssetEntity>> groupedVideos;

  final List<String> fechasImagenes;
  final List<String> fechasGifs;
  final List<String> fechasVideos;

  DatosArchivos({
    required this.todos,
    required this.imagenes,
    required this.gifs,
    required this.videos,
    required this.groupedImages,
    required this.groupedGifs,
    required this.groupedVideos,
    required this.fechasImagenes,
    required this.fechasGifs,
    required this.fechasVideos,
  });
}

Future<DatosArchivos> cargarArchivosDesdeFolder(AssetPathEntity folder) async {
  final allFiles = await folder.getAssetListPaged(page: 0, size: 10000);

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

  final groupedImages = agruparPorFecha(tempImages);
  final groupedGifs = agruparPorFecha(tempGifs);
  final groupedVideos = agruparPorFecha(tempVideos);

  final orderedImageDates = obtenerFechasOrdenadas(groupedImages);
  final orderedGifDates = obtenerFechasOrdenadas(groupedGifs);
  final orderedVideoDates = obtenerFechasOrdenadas(groupedVideos);

  return DatosArchivos(
    todos: allFiles,
    imagenes: tempImages,
    gifs: tempGifs,
    videos: tempVideos,
    groupedImages: groupedImages,
    groupedGifs: groupedGifs,
    groupedVideos: groupedVideos,
    fechasImagenes: orderedImageDates,
    fechasGifs: orderedGifDates,
    fechasVideos: orderedVideoDates,
  );
}

List<AssetEntity> getOrderedVisibleList(
    Map<String, List<AssetEntity>> groupedImages,
    Map<String, List<AssetEntity>> groupedGifs,
    Map<String, List<AssetEntity>> groupedVideos,
    List<String> orderedImageDates,
    List<String> orderedGifDates,
    List<String> orderedVideoDates,
    String selectedFilter) {
  final Map<String, List<AssetEntity>> grouped = {
    'Imágenes': groupedImages,
    'GIFs': groupedGifs,
    'Videos': groupedVideos,
  }[selectedFilter]!;

  final List<String> orderedDates = {
    'Imágenes': orderedImageDates,
    'GIFs': orderedGifDates,
    'Videos': orderedVideoDates,
  }[selectedFilter]!;

  List<AssetEntity> orderedList = [];
  for (var date in orderedDates) {
    orderedList.addAll(grouped[date]!);
  }
  return orderedList;
}
