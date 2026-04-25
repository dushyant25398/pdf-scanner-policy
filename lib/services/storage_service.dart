import 'dart:io';
import 'package:flutter/foundation.dart';
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

  static Future<void> saveDocumentPath(String path, {String folder = 'Uncategorized'}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> docs = prefs.getStringList(_storageKey) ?? [];
    if (!docs.contains(path)) {
      docs.insert(0, path);
      await prefs.setStringList(_storageKey, docs);
    }

    // Sync with Hive for metadata persistence
    try {
      final box = Hive.box('pdfBox');
      final existingItemIndex = box.values.toList().indexWhere((item) => item['path'] == path);
      
      if (existingItemIndex == -1) {
        await box.add({
          'path': path,
          'date': DateTime.now().toIso8601String(),
          'folder': folder,
        });
      } else {
        // Update folder if it changed
        final item = box.getAt(existingItemIndex);
        item['folder'] = folder;
        await box.putAt(existingItemIndex, item);
      }
    } catch (e) {
      debugPrint("Hive error: $e");
    }
  }

  static Future<String> getDocumentFolder(String path) async {
    try {
      final box = Hive.box('pdfBox');
      final item = box.values.firstWhere((element) => element['path'] == path, orElse: () => null);
      return item?['folder'] ?? 'Uncategorized';
    } catch (e) {
      return 'Uncategorized';
    }
  }

  static Future<void> updateDocumentFolder(String path, String folder) async {
    try {
      final box = Hive.box('pdfBox');
      final index = box.values.toList().indexWhere((item) => item['path'] == path);
      if (index != -1) {
        final item = Map<String, dynamic>.from(box.getAt(index));
        item['folder'] = folder;
        await box.putAt(index, item);
      } else {
        await saveDocumentPath(path, folder: folder);
      }
    } catch (e) {
      debugPrint("Update folder error: $e");
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

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_premium') ?? false;
  }

  static Future<void> setPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', value);
  }

  static Future<List<File>> getAllPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedPaths = prefs.getStringList(_storageKey) ?? [];
    
    final List<File> files = [];
    final List<String> validPaths = [];

    // Parallelize file existence checks
    final existenceResults = await Future.wait(
      savedPaths.map((path) async {
        final file = File(path);
        final exists = await file.exists();
        return exists ? file : null;
      })
    );

    for (int i = 0; i < existenceResults.length; i++) {
      final file = existenceResults[i];
      if (file != null) {
        files.add(file);
        validPaths.add(savedPaths[i]);
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
