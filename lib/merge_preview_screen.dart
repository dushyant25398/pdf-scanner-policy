import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path_provider/path_provider.dart';

class MergePreviewScreen extends StatefulWidget {
  final List<File> pdfs;

  const MergePreviewScreen({super.key, required this.pdfs});

  @override
  State<MergePreviewScreen> createState() => _MergePreviewScreenState();
}

class _MergePreviewScreenState extends State<MergePreviewScreen> {
  late List<File> selectedPdfs;

  @override
  void initState() {
    super.initState();
    selectedPdfs = List.from(widget.pdfs);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final File item = selectedPdfs.removeAt(oldIndex);
      selectedPdfs.insert(newIndex, item);
    });
  }

  void _removePdf(int index) {
    setState(() {
      selectedPdfs.removeAt(index);
    });
    if (selectedPdfs.isEmpty) {
      Navigator.pop(context);
    }
  }

  Future<void> _showRenameDialog() async {
    if (selectedPdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least 2 PDFs to merge")),
      );
      return;
    }

    TextEditingController controller = TextEditingController(
      text: "merged_${DateTime.now().millisecondsSinceEpoch}",
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Merged PDF Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "File Name",
            suffixText: ".pdf",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _mergePdfs(controller.text.trim());
            },
            child: const Text("Merge"),
          ),
        ],
      ),
    );
  }

  Future<void> _mergePdfs(String fileName) async {
    if (selectedPdfs.length < 2 || fileName.isEmpty) return;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final sf.PdfDocument finalDoc = sf.PdfDocument();

      for (var file in selectedPdfs) {
        final sf.PdfDocument inputDoc = sf.PdfDocument(inputBytes: await file.readAsBytes());
        // Merge all pages
        for (int i = 0; i < inputDoc.pages.count; i++) {
          finalDoc.pages.add().graphics.drawPdfTemplate(
            inputDoc.pages[i].createTemplate(),
            Offset.zero,
          );
        }
        inputDoc.dispose();
      }

      final dir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory("${dir.path}/PDFs");
      if (!pdfDir.existsSync()) await pdfDir.create();
      
      final mergedFile = File("${pdfDir.path}/$fileName.pdf");
      await mergedFile.writeAsBytes(finalDoc.saveSync());
      finalDoc.dispose();

      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDFs Merged Successfully ✅")),
        );
        Navigator.pop(context, mergedFile); // Return to home with merged file
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Merge failed: $e ❌")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Merge & Reorder", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Long press and drag to reorder",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  itemCount: selectedPdfs.length,
                  onReorder: _reorder,
                  itemBuilder: (context, index) {
                    final file = selectedPdfs[index];
                    final fileName = file.path.split(Platform.pathSeparator).last;
                    final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

                    return Padding(
                      key: ValueKey(file.path),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                              ),
                              title: Text(
                                fileName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                "$fileSize KB",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                    onPressed: () => _removePdf(index),
                                  ),
                                  const Icon(Icons.drag_handle, color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      elevation: 0,
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
                    ),
                    onPressed: selectedPdfs.length < 2 ? null : _showRenameDialog,
                    icon: const Icon(Icons.merge_type),
                    label: Text(
                      "Merge ${selectedPdfs.length} Files",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
