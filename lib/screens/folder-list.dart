import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/file-list.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FolderListScreen extends StatefulWidget {
  @override
  _FolderListScreenState createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  List<Directory> folders = [];
  List<Directory> filtered = [];
  TextEditingController searchCtrl = TextEditingController();
  String mainPath = '/storage/emulated/0/NebulaVault';
  final ScrollController _scrollController = ScrollController();
  Map<String, String> portadasSeleccionadas = {};

  @override
  void initState() {
    super.initState();
    _loadPortadas();
    _preguntarPermisos();
  }

  Future<void> _loadPortadas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('portadas_seleccionadas');
    if (data != null) {
      setState(() {
        portadasSeleccionadas = Map<String, String>.from(jsonDecode(data));
      });
    }
  }

  Future<Widget> _buildPortadaWidget(Directory d) async {
    if (portadasSeleccionadas.containsKey(d.path)) {
      final coverId = portadasSeleccionadas[d.path]!;
      // Buscar el asset con ese id
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.image,
      );
      // Buscar la carpeta matching
      final folderName = d.path.split('/').last;
      final matchingPath = paths.firstWhere(
        (p) => p.name.toLowerCase() == folderName.toLowerCase(),
        orElse: () => paths.first,
      );

      // Buscar asset con id coverId
      final List<AssetEntity> assets =
          await matchingPath.getAssetListPaged(page: 0, size: 1000);
      AssetEntity? coverAsset;
      try {
        coverAsset = assets.firstWhere((a) => a.id == coverId);
      } catch (_) {
        coverAsset = null;
      }

      if (coverAsset != null) {
        final file = await coverAsset.file;
        if (file != null && await file.exists()) {
          return Image.file(
            file,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          );
        }
      }
    }

    // Si no hay portada seleccionada o no se encontró, mostrar icono de carpeta
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.amber.shade700,
      ),
      child: const Icon(Icons.folder, size: 50, color: Colors.white),
    );
  }

  Future<void> _savePortadas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(portadasSeleccionadas);
    await prefs.setString('portadas_seleccionadas', data);
  }

  Future<void> _preguntarPermisos() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();

      if (status.isGranted) {
        _cargarCarpetas();
      } else {
        Fluttertoast.showToast(msg: 'Se necesitan permisos para continuar.');
        openAppSettings(); // Lanza la pantalla de configuración si el usuario rechaza
      }
    } else {
      _cargarCarpetas();
    }
  }

  void _cargarCarpetas() async {
    List<Directory> resultFolders = [];
    final nebulaDir = Directory('/storage/emulated/0/NebulaVault');

    // Traer subcarpetas de NebulaVault (solo si existen y tienen contenido)
    if (await nebulaDir.exists()) {
      final subDirs = nebulaDir.listSync().whereType<Directory>();
      for (final dir in subDirs) {
        final hasFiles = await _folderHasMedia(dir);
        if (hasFiles) resultFolders.add(dir);
      }
    }

    // Para las otras rutas, solo mostrar imágenes dentro directamente (sin subcarpetas)
    final flatPaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Music',
    ];

    for (final path in flatPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        final hasMedia =
            await _folderHasMedia(dir, includeOnlyDirectFiles: true);
        if (hasMedia) resultFolders.add(dir);
      }
    }

    // Ordenar
    resultFolders.sort((a, b) => a.path
        .split('/')
        .last
        .toLowerCase()
        .compareTo(b.path.split('/').last.toLowerCase()));

    setState(() {
      folders = resultFolders;
      filtered = resultFolders;
    });
  }

  Future<bool> _folderHasMedia(Directory dir,
      {bool includeOnlyDirectFiles = false}) async {
    final mediaExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.mp4',
      '.gif',
      '.mov',
      '.webp'
    ];
    try {
      final contents = includeOnlyDirectFiles
          ? dir.listSync(recursive: false, followLinks: false)
          : dir.listSync(recursive: true, followLinks: false);

      for (final f in contents) {
        if (f is File) {
          final ext = f.path.toLowerCase();
          if (mediaExtensions.any((e) => ext.endsWith(e))) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  void _filtrarCarpetas(String q) => setState(() {
        filtered = q.isEmpty
            ? folders
            : folders
                .where((d) => d.path
                    .split('/')
                    .last
                    .toLowerCase()
                    .contains(q.toLowerCase()))
                .toList();
      });

  Future<void> _renombrarCarpetas(Directory folder) async {
    final oldName = folder.path.split('/').last;
    final TextEditingController ctrl = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar Carpeta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nuevo nombre'),
        ),
        actions: [
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context)),
          ElevatedButton(
              child: const Text('Renombrar'),
              onPressed: () => Navigator.pop(context, ctrl.text.trim())),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final newPath = '${folder.parent.path}/$newName';
      try {
        await folder.rename(newPath);
        Fluttertoast.showToast(msg: 'Carpeta renombrada.');
        _cargarCarpetas();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error al renombrar.');
      }
    }
  }

  Future<void> _borrarCarpeta(Directory d) async {
    /* eliminar lógica + reload */
  }

  Future<void> _seleccionarPortada(Directory d) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      PhotoManager.openSetting();
      return;
    }

    final folderName = d.path.split('/').last;

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.image,
    );

    // Mostrar indicador de carga mientras se prepara todo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final matchingPath = paths.firstWhere(
      (p) => p.name.toLowerCase() == folderName.toLowerCase(),
      orElse: () => paths.first,
    );

    List<AssetEntity> images = await matchingPath.getAssetListPaged(
      page: 0,
      size: 1000,
    );

    if (images.isEmpty) {
      Navigator.pop(context); // Cierra el loading
      Fluttertoast.showToast(
          msg: 'No se encontraron imágenes en esta carpeta.');
      return;
    }

    // Ordenar de más reciente a más antigua
    images.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    // Agrupar por fecha
    final Map<String, List<AssetEntity>> grouped = {};
    final fmt = DateFormat('dd-MM-yyyy');
    for (var img in images) {
      final key = fmt.format(img.createDateTime);
      grouped.putIfAbsent(key, () => []).add(img);
    }

    final scrollController = ScrollController();

    // Cierra el diálogo de carga
    Navigator.pop(context);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Seleccionar portada',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Scrollbar(
            controller: scrollController,
            interactive: true,
            radius: const Radius.circular(8),
            thickness: 40,
            child: ListView(
              controller: scrollController,
              children: grouped.entries.map((entry) {
                final date = entry.key;
                final list = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        date,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemBuilder: (_, i) {
                        final image = list[i];
                        final isSelected =
                            portadasSeleccionadas[d.path] == image.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              portadasSeleccionadas[d.path] = image.id;
                            });
                            _savePortadas();

                            Navigator.pop(context);
                            Fluttertoast.showToast(msg: 'Portada actualizada');
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image(
                                  image: AssetEntityImageProvider(image,
                                      thumbnailSize:
                                          const ThumbnailSize(200, 200)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (isSelected)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.4),
                                    child: const Icon(Icons.check_circle,
                                        color: Colors.green, size: 40),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NebulaVault (${filtered.length} Carpetas)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: searchCtrl,
              onChanged: _filtrarCarpetas,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar carpeta...',
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          thickness: 40,
          radius: const Radius.circular(10),
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 8, top: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.75, // Ajusta la altura de las celdas
            ),
            itemCount: filtered.length,
            itemBuilder: (ctx, index) {
              final d = filtered[index];
              final name = d.path.split('/').last;
              return GestureDetector(
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => FileListScreen(
                      folder: d,
                      allFolders: folders,
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          FutureBuilder<Widget>(
                            future: _buildPortadaWidget(d),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(
                                  width: double.infinity,
                                  height: 180,
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              return ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: snapshot.data ?? Container(),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: PopupMenuButton<String>(
                          icon:
                              const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            switch (value) {
                              case 'cover':
                                _seleccionarPortada(d);
                                break;
                              case 'rename':
                                _renombrarCarpetas(d);
                                break;
                              case 'delete':
                                _borrarCarpeta(d);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'cover', child: Text('Cambiar portada')),
                            const PopupMenuItem(
                                value: 'rename', child: Text('Renombrar')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
