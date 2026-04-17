import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class StorageService {
  static const String _storageKey = 'documents';

  static Future<Directory> getPdfDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/PDFScannerPro');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    return folder;
  }

  static Future<void> saveDocumentPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docs = prefs.getStringList(_storageKey) ?? [];
    if (!docs.contains(path)) {
      docs.insert(0, path);
      await prefs.setStringList(_storageKey, docs);
    }

    // Sync with Hive for metadata persistence
    try {
      final box = Hive.box('pdfBox');
      final alreadyInHive = box.values.any((item) => item['path'] == path);
      if (!alreadyInHive) {
        await box.add({
          'path': path,
          'date': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Box might not be open in some contexts, though it's opened in main()
    }
  }

  static Future<void> removeDocumentPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docs = prefs.getStringList(_storageKey) ?? [];
    docs.remove(path);
    await prefs.setStringList(_storageKey, docs);

    // Sync with Hive
    try {
      final box = Hive.box('pdfBox');
      final indexInHive = box.values.toList().indexWhere((item) => item['path'] == path);
      if (indexInHive != -1) {
        await box.deleteAt(indexInHive);
      }
    } catch (e) {
      // Handle potential Hive errors
    }
  }

  static Future<List<File>> getAllPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedPaths = prefs.getStringList(_storageKey) ?? [];
    
    final List<File> files = [];
    final List<String> validPaths = [];

    for (String path in savedPaths) {
      final file = File(path);
      if (await file.exists()) {
        files.add(file);
        validPaths.add(path);
      }
    }

    // Sync back valid paths if some files were deleted manually
    if (validPaths.length != savedPaths.length) {
      await prefs.setStringList(_storageKey, validPaths);
    }

    // Fallback: If SharedPreferences is empty but folder isn't (e.g., first run after update)
    if (files.isEmpty) {
      final folder = await getPdfDirectory();
      final entities = folder.listSync();
      final scannedFiles = entities
          .where((entity) => entity is File && entity.path.toLowerCase().endsWith(".pdf"))
          .map((e) => File(e.path))
          .toList();
      
      if (scannedFiles.isNotEmpty) {
        scannedFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        for (var f in scannedFiles) {
          await saveDocumentPath(f.path);
        }
        return scannedFiles;
      }
    }

    return files;
  }
}
