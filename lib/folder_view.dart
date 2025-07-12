import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'image_list.dart';

class FolderViewScreen extends StatefulWidget {
  @override
  _FolderViewScreenState createState() => _FolderViewScreenState();
}

class _FolderViewScreenState extends State<FolderViewScreen> {
  Directory? directorio;
  List<Directory> folders = [];
  List<Directory> foldersFiltrados = [];
  List<Map<String, dynamic>> detallesFolder = [];
  bool cuadricula = true;
  String busqueda = '';
  String ordernarPor = 'none';
  Map<String, String> portadas = {};
  Map<String, BoxFit> portadasFit = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _obtenerDirectorioInicial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _obtenerDirectorioInicial() async {
    // Lista de rutas raíz a explorar
    final List<String> rutasBase = [
      '/storage/emulated/0/NebulaVault',
    ];

    List<Directory> todasLasCarpetas = [];

    for (final ruta in rutasBase) {
      final baseDir = Directory(ruta);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final subcarpetas = baseDir.listSync().whereType<Directory>().toList();
      todasLasCarpetas.addAll(subcarpetas);
    }

    final prefs = await SharedPreferences.getInstance();
    final savedCovers = await _cargarPortadas();
    final savedFits = prefs.getKeys().fold<Map<String, BoxFit>>({}, (map, key) {
      if (key.startsWith('fit_')) {
        final rawFit = prefs.getString(key)!;
        final folderPath = key.replaceFirst('fit_', '');
        map[folderPath] = _boxFitFromString(rawFit);
      }
      return map;
    });

    setState(() {
      directorio = Directory(
          '/storage/emulated/0/NebulaVault'); // Puedes dejarlo como principal
      folders = todasLasCarpetas;
      foldersFiltrados = List.from(todasLasCarpetas);
      portadas = savedCovers;
      portadasFit = savedFits;
    });

    _aplicarOrdenamiento();
  }

  Future<Map<String, String>> _cargarPortadas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().fold<Map<String, String>>({}, (map, key) {
      if (!key.startsWith('fit_')) {
        map[key] = prefs.getString(key)!;
      }
      return map;
    });
  }

  BoxFit _boxFitFromString(String fit) {
    switch (fit) {
      case 'cover':
        return BoxFit.cover;
      case 'fill':
        return BoxFit.fill;
      case 'contain':
        return BoxFit.contain;
      default:
        return BoxFit.cover;
    }
  }

  String _boxFitToString(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.contain:
        return 'contain';
      default:
        return 'cover';
    }
  }

  Future<void> _cargarDetallesDeCarpetas(List<Directory> folderList) async {
    List<Map<String, dynamic>> nuevaLista = [];

    for (var folder in folderList) {
      // Agrega valores iniciales en blanco
      nuevaLista
          .add({'path': folder.path, 'sizeMB': '...', 'fileCount': '...'});
    }

    setState(() {
      detallesFolder = List.from(nuevaLista);
    });

    // Carga en segundo plano sin bloquear
    for (int i = 0; i < folderList.length; i++) {
      final stats = await _obtenerDetallesFolder(folderList[i]);
      nuevaLista[i] = {
        'path': folderList[i].path,
        'sizeMB': stats['sizeMB'],
        'fileCount': stats['fileCount']
      };

      // Actualiza la UI solo para ese elemento
      setState(() {
        detallesFolder = List.from(nuevaLista);
      });
    }

    _aplicarOrdenamiento();
  }

  Future<Map<String, dynamic>> _obtenerDetallesFolder(Directory folder) async {
    int fileCount = 0;
    int totalBytes = 0;
    final files = folder.listSync(recursive: true).whereType<File>();
    for (var file in files) {
      fileCount++;
      totalBytes += await file.length();
    }
    return {
      'sizeMB': (totalBytes / (1024 * 1024)).toStringAsFixed(2),
      'fileCount': fileCount
    };
  }

  void _aplicarOrdenamiento() {
    if (ordernarPor == 'size') {
      foldersFiltrados.sort((a, b) {
        final aSize = double.tryParse(detallesFolder
                .firstWhere((e) => e['path'] == a.path)['sizeMB']) ??
            0;
        final bSize = double.tryParse(detallesFolder
                .firstWhere((e) => e['path'] == b.path)['sizeMB']) ??
            0;
        return bSize.compareTo(aSize);
      });
    } else if (ordernarPor == 'count') {
      foldersFiltrados.sort((a, b) {
        final aCount =
            detallesFolder.firstWhere((e) => e['path'] == a.path)['fileCount'];
        final bCount =
            detallesFolder.firstWhere((e) => e['path'] == b.path)['fileCount'];
        return bCount.compareTo(aCount);
      });
    } else {
      foldersFiltrados.sort((a, b) => a.path
          .split('/')
          .last
          .toLowerCase()
          .compareTo(b.path.split('/').last.toLowerCase()));
    }
  }

  Widget _vistaCuadriculada(Directory folder, int index) {
    final name = folder.path.split('/').last;
    final stats = detallesFolder.firstWhere((e) => e['path'] == folder.path,
        orElse: () => {'sizeMB': '0.00', 'fileCount': 0});
    final coverPath = portadas[folder.path];
    final cover = coverPath != null && File(coverPath).existsSync()
        ? FileImage(File(coverPath))
        : null;
    final fit = portadasFit[folder.path] ?? BoxFit.cover;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: ScaleAnimation(
        scale: 0.95,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ImageListScreen(folder: folder)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 128,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.withOpacity(0.2),
                      image: cover != null
                          ? DecorationImage(image: cover, fit: fit)
                          : null,
                    ),
                    child: cover == null
                        ? const Center(child: Icon(Icons.folder, size: 40))
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${stats['fileCount']} archivos - ${stats['sizeMB']} MB',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'editar') {
                    _renombrarCarpeta(folder);
                  } else if (value == 'portada') {
                    _setPortadasFolderFromApp(folder.path);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(
                      value: 'portada', child: Text('Seleccionar portada')),
                ],
                icon: const Icon(Icons.more_vert, size: 25),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPortadasFolderFromApp(String folderPath) async {
    List<File> files = Directory(folderPath)
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.toLowerCase().endsWith('.jpeg') ||
            file.path.toLowerCase().endsWith('.jpg') ||
            file.path.toLowerCase().endsWith('.png') ||
            file.path.toLowerCase().endsWith('.gif') ||
            file.path.toLowerCase().endsWith('.webp'))
        .toList();

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            backgroundColor: Color.fromARGB(221, 65, 65, 65),
            content: Text(
              "No hay imágenes en esta carpeta",
              style: TextStyle(color: Colors.white),
            )),
      );
      return;
    }

    // Ordenar archivos por fecha descendente para mostrar lo más reciente arriba
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    // Agrupar por mes y año
    final Map<String, List<File>> grouped = {};
    for (var file in files) {
      final date = file.lastModifiedSync();
      final key = DateFormat('MMMM yyyy', 'es_MX').format(date);
      grouped.putIfAbsent(key, () => []).add(file);
    }

    // Navegar a pantalla selección portada optimizada
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => VistaPreviaPortadaModal(files: files),
    );

    if (resultado != null && resultado is Map<String, dynamic>) {
      final String selectedPath = resultado['path'];
      final BoxFit selectedFit = resultado['fit'];

      // Guardar portada y estilo en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(folderPath, selectedPath);
      await prefs.setString('fit_$folderPath', _boxFitToString(selectedFit));

      setState(() {
        portadas[folderPath] = selectedPath;
        portadasFit[folderPath] = selectedFit;
      });
    }
  }

  void _cambiarModoVista() {
    setState(() => cuadricula = !cuadricula);
  }

  void _filtrarCarpetas(String query) {
    setState(() {
      busqueda = query;
      foldersFiltrados = folders
          .where((f) => f.path
              .split('/')
              .last
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
      _aplicarOrdenamiento();
    });
  }

  Widget _vistaDeLista(Directory folder) {
    final coverPath = portadas[folder.path];
    final fit = portadasFit[folder.path] ?? BoxFit.cover;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: coverPath != null && File(coverPath).existsSync()
                ? Image.file(File(coverPath), fit: fit)
                : const Icon(Icons.folder, size: 50),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'portada') {
                _setPortadasFolderFromApp(folder.path);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(
                  value: 'portada', child: Text('Seleccionar portada')),
            ],
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _renombrarCarpeta(Directory folder) async {
    final controller = TextEditingController(text: folder.path.split('/').last);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Editar nombre de carpeta"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nuevo nombre"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final nuevoNombre = controller.text.trim();
              if (nuevoNombre.isEmpty) return;

              final nuevoPath = '${folder.parent.path}/$nuevoNombre';
              final nuevoDir = Directory(nuevoPath);

              if (!await nuevoDir.exists()) {
                await folder.rename(nuevoPath);
                _obtenerDirectorioInicial();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarCalculoEstadisticas() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Calculando estadísticas..."),
          ],
        ),
      ),
    );

    await _cargarDetallesDeCarpetas(folders);

    Navigator.pop(context); // Cierra el diálogo al terminar
  }

  void _crearNuevoFolder() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Crear nueva carpeta"),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: "Nombre de la carpeta"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Crear"),
            onPressed: () async {
              final name = _controller.text.trim();
              if (name.isEmpty) return;

              final newFolder = Directory('${directorio!.path}/$name');
              if (!await newFolder.exists()) {
                await newFolder.create();
                final stats = await _obtenerDetallesFolder(newFolder);
                setState(() {
                  folders.add(newFolder);
                  detallesFolder.add({
                    'path': newFolder.path,
                    'sizeMB': stats['sizeMB'],
                    'fileCount': stats['fileCount']
                  });
                  _filtrarCarpetas(busqueda);
                });
              }

              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = directorio == null;

// App bar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nebula Vault'),
        actions: [],
      ),

      // cuerpo del codigo
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: ElevatedButton.icon(
                        onPressed: _iniciarCalculoEstadisticas,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Ver'),
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(cuadricula ? Icons.view_list : Icons.grid_view),
                      onPressed: _cambiarModoVista,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list),
                      onSelected: (value) {
                        setState(() {
                          ordernarPor = value;
                          _aplicarOrdenamiento();
                        });
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                            value: 'size', child: Text('Ordenar por tamaño')),
                        const PopupMenuItem(
                            value: 'count',
                            child: Text('Ordenar por cantidad')),
                        const PopupMenuItem(
                            value: 'none', child: Text('A - Z')),
                      ],
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.45,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 1),
                        child: TextField(
                          onChanged: (valor) {
                            busqueda = valor;
                            _filtrarCarpetas(busqueda);
                          },
                          decoration: InputDecoration(
                            fillColor: Colors.white.withOpacity(0.1),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '${foldersFiltrados.length} carpeta${foldersFiltrados.length == 1 ? '' : 's'} encontrada${foldersFiltrados.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    interactive: true,
                    trackVisibility: true,
                    scrollbarOrientation: ScrollbarOrientation.right,
                    thickness: 30,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: cuadricula
                          ? AnimationLimiter(
                              child: GridView.count(
                                controller: _scrollController,
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 20,
                                children: List.generate(
                                  foldersFiltrados.length,
                                  (i) => _vistaCuadriculada(
                                      foldersFiltrados[i], i),
                                ),
                              ),
                            )
                          : AnimationLimiter(
                              child: ListView.separated(
                                controller: _scrollController,
                                itemCount: foldersFiltrados.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (_, i) {
                                  final folder = foldersFiltrados[i];
                                  final name = folder.path.split('/').last;
                                  final stats = detallesFolder.firstWhere(
                                      (e) => e['path'] == folder.path);
                                  return ListTile(
                                    leading: _vistaDeLista(folder),
                                    title: Center(
                                      child: Text(
                                        '$name - ${stats['fileCount']} archivos - ${stats['sizeMB']} MB',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ImageListScreen(
                                            folder: folder,
                                          ),
                                        ),
                                      );
                                    },
                                    onLongPress: () =>
                                        _setPortadasFolderFromApp(folder.path),
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Pantalla para seleccionar portada con opción de estilo BoxFit
class _SeleccionarPortadaScreen extends StatefulWidget {
  final String folderPath;
  final Map<String, List<File>> groupedFiles;

  const _SeleccionarPortadaScreen({
    Key? key,
    required this.folderPath,
    required this.groupedFiles,
  }) : super(key: key);

  @override
  State<_SeleccionarPortadaScreen> createState() =>
      _SeleccionarPortadaScreenState();
}

class _SeleccionarPortadaScreenState extends State<_SeleccionarPortadaScreen> {
  late String? selectedFilePath;
  BoxFit selectedFit = BoxFit.cover;

  @override
  void initState() {
    super.initState();
    selectedFilePath = null;
  }

  void _confirmarSeleccion() {
    if (selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen o video primero')),
      );
      return;
    }
    Navigator.pop(context, {'path': selectedFilePath!, 'fit': selectedFit});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar portada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmarSeleccion,
          ),
        ],
      ),
      body: Column(
        children: [
          // Opciones de estilo para portada
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('Cubrir'),
                  selected: selectedFit == BoxFit.cover,
                  onSelected: (_) {
                    setState(() {
                      selectedFit = BoxFit.cover;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Ajustar'),
                  selected: selectedFit == BoxFit.contain,
                  onSelected: (_) {
                    setState(() {
                      selectedFit = BoxFit.contain;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Rellenar'),
                  selected: selectedFit == BoxFit.fill,
                  onSelected: (_) {
                    setState(() {
                      selectedFit = BoxFit.fill;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                children: widget.groupedFiles.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          children: entry.value.map((file) {
                            final isSelected = file.path == selectedFilePath;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedFilePath = file.path;
                                });
                              },
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VistaPreviaPortadaModal extends StatefulWidget {
  final List<File> files;

  const VistaPreviaPortadaModal({Key? key, required this.files})
      : super(key: key);

  @override
  State<VistaPreviaPortadaModal> createState() =>
      _VistaPreviaPortadaModalState();
}

class _VistaPreviaPortadaModalState extends State<VistaPreviaPortadaModal> {
  String? selectedPath;
  BoxFit selectedFit = BoxFit.cover;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar portada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedPath != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(),
                image: DecorationImage(
                  image: FileImage(File(selectedPath!)),
                  fit: selectedFit,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: const Text('Cubrir'),
                selected: selectedFit == BoxFit.cover,
                onSelected: (_) => setState(() => selectedFit = BoxFit.cover),
              ),
              ChoiceChip(
                label: const Text('Ajustar'),
                selected: selectedFit == BoxFit.contain,
                onSelected: (_) => setState(() => selectedFit = BoxFit.contain),
              ),
              ChoiceChip(
                label: const Text('Rellenar'),
                selected: selectedFit == BoxFit.fill,
                onSelected: (_) => setState(() => selectedFit = BoxFit.fill),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(1),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // Número de columnas en la cuadrícula
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: widget.files.length,
              itemBuilder: (_, i) {
                final path = widget.files[i].path;
                return GestureDetector(
                  onTap: () => setState(() => selectedPath = path),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      if (selectedPath == path)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: selectedPath != null
              ? () => Navigator.pop(
                  context, {'path': selectedPath!, 'fit': selectedFit})
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
