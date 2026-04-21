import 'dart:io';
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'edit_pdf_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class DocumentPickerScreen extends StatefulWidget {
  final String title;
  final Function(File) onFileSelected;

  const DocumentPickerScreen({
    super.key, 
    required this.title,
    required this.onFileSelected,
  });

  @override
  State<DocumentPickerScreen> createState() => _DocumentPickerScreenState();
}

class _DocumentPickerScreenState extends State<DocumentPickerScreen> {
  List<File> pdfFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => isLoading = true);
    final files = await StorageService.getAllPdfs();
    setState(() {
      pdfFiles = files;
      isLoading = false;
    });
  }

  Future<void> _pickFromStorage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      widget.onFileSelected(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _pickFromStorage,
            icon: const Icon(Icons.file_upload),
            label: const Text("Internal Storage"),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pdfFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("No app documents found"),
                      ElevatedButton(
                        onPressed: _pickFromStorage,
                        child: const Text("Pick from Internal Storage"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pdfFiles.length,
                  itemBuilder: (context, index) {
                    final file = pdfFiles[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        title: Text(file.path.split(Platform.pathSeparator).last),
                        subtitle: Text("${(file.lengthSync() / 1024).toStringAsFixed(1)} KB"),
                        onTap: () => widget.onFileSelected(file),
                      ),
                    );
                  },
                ),
    );
  }
}
