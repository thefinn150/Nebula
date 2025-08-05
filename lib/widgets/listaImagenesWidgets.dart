import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

//boton de icono de filtro
Future<String?> showFilterMenu(
  BuildContext context,
  List<AssetEntity> images,
  List<AssetEntity> gifs,
  List<AssetEntity> videos,
  String selectedFilter,
) async {
  return await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Filtrar por:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Divider(color: Colors.white24),
          for (String type in ['Imágenes', 'GIFs', 'Videos'])
            if ((type == 'Imágenes' && images.isNotEmpty) ||
                (type == 'GIFs' && gifs.isNotEmpty) ||
                (type == 'Videos' && videos.isNotEmpty))
              ListTile(
                title: Text(type, style: const TextStyle(color: Colors.white)),
                trailing: selectedFilter == type
                    ? const Icon(Icons.check, color: Colors.lightBlueAccent)
                    : null,
                onTap: () {
                  Navigator.pop(context, type); // Esto es lo que retorna
                },
              ),
          const SizedBox(height: 16),
        ],
      );
    },
  );
}

// aqui estan las fechas y el icono de seleccionar todos los de esa fecha
Widget buildSectionHeader(
  String title,
  String date,
  List<String> selectedDates,
  Map<String, List<AssetEntity>> groupedImages,
  Map<String, List<AssetEntity>> groupedGifs,
  Map<String, List<AssetEntity>> groupedVideos,
  Set<String> selectedIds,
  bool isSel,
  String selectedFilter,
  void Function(void Function()) setState, {
  required void Function(bool) onSelectionModeChanged,
}) {
  return SliverToBoxAdapter(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: selectedDates.contains(date)
                ? Icon(Icons.circle_rounded, color: Colors.blueAccent)
                : Icon(Icons.circle_outlined, color: Colors.white),
            onPressed: () async {
              selectedDates.contains(date)
                  ? selectedDates.remove(date)
                  : selectedDates.add(date);

              setState(() {});
              final Map<String, List<AssetEntity>> grouped = {
                'Imágenes': groupedImages,
                'GIFs': groupedGifs,
                'Videos': groupedVideos,
              }[selectedFilter]!;

              if (!selectedDates.contains(date)) {
                for (var asset in grouped[date]!) {
                  selectedIds.remove(asset.id);
                }
              } else {
                for (var asset in grouped[date]!) {
                  selectedIds.add(asset.id);
                }
              }
              if (!isSel) {
                onSelectionModeChanged(
                    true); // ✅ activa selección si no estaba activa
              }
              setState;
            },
          ),
        ],
      ),
    ),
  );
}
