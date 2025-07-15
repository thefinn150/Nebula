// file_details_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:intl/intl.dart';

void showFileDetailsDialog(BuildContext context, File file) {
  final String fileName = file.path.split('/').last;
  final String fileSize =
      (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
  final String filePath = file.path;
  final String fileDate =
      DateFormat('yyyy-MM-dd HH:mm').format(file.statSync().changed);

  void copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado al portapapeles')),
    );
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Detalles del archivo',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDetailTile(
            icon: Icons.insert_drive_file,
            label: 'Nombre',
            value: fileName,
            onTap: () => copyToClipboard('Nombre', fileName),
          ),
          const Divider(color: Colors.white24),
          _buildDetailTile(
            icon: Icons.storage,
            label: 'Tamaño',
            value: '$fileSize MB',
            onTap: () => copyToClipboard('Tamaño', '$fileSize MB'),
          ),
          const Divider(color: Colors.white24),
          _buildDetailTile(
            icon: Icons.folder,
            label: 'Ruta',
            value: filePath,
            onTap: () => copyToClipboard('Ruta', filePath),
          ),
          const Divider(color: Colors.white24),
          _buildDetailTile(
            icon: Icons.calendar_today,
            label: 'Creado',
            value: fileDate,
            onTap: () => copyToClipboard('Fecha', fileDate),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

Widget _buildDetailTile({
  required IconData icon,
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.copy, color: Colors.white24, size: 18),
        ],
      ),
    ),
  );
}
