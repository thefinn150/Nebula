// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

Future<void> mostrarDetalles(BuildContext context, AssetEntity asset) async {
  final file = await asset.file;
  if (file == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el archivo')));
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) {
      final details = <String, String>{
        'Nombre': file.uri.pathSegments.last,
        'Ruta': file.path,
        'Tipo': asset.mimeType ?? 'Desconocido',
        'Tamaño':
            '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
        'Fecha creación': asset.createDateTime.toString(),
        'Fecha modificación': asset.modifiedDateTime.toString(),
        'Duración (seg)': asset.videoDuration.inSeconds.toString(),
        'ID': asset.id,
      };

      Widget detailRow(String label, String value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text('$label:',
                    style: const TextStyle(color: Colors.white70)),
              ),
              Expanded(
                flex: 5,
                child: SelectableText(value,
                    style: const TextStyle(color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$label copiado al portapapeles')));
                },
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Detalles del archivo',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const Divider(color: Colors.white54),
              ...details.entries.map((e) => detailRow(e.key, e.value)),
            ],
          ),
        ),
      );
    },
  );
}
