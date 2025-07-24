import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';

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
