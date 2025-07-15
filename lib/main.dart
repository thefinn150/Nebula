import 'package:flutter/material.dart';
import 'package:nebula_vault/screens/folder-list.dart';

void main() => runApp(NebulaVaultApp());

class NebulaVaultApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NebulaVault',
        theme: ThemeData.dark(),
        home: FolderListScreen(),
        debugShowCheckedModeBanner: false,
      );
}
