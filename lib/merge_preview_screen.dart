import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';

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

      final folder = await StorageService.getPdfDirectory();
      
      final mergedFile = File("${folder.path}/$fileName.pdf");
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Merge & Reorder",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Long press and drag items to change their order in the final PDF.",
                    style: TextStyle(
                      color: isDark ? Colors.amber[200] : const Color(0xFF92400E),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: selectedPdfs.length,
              onReorder: _reorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 10, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: Colors.black26,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final file = selectedPdfs[index];
                final fileName = file.path.split(Platform.pathSeparator).last;
                final fileSize = (file.lengthSync() / 1024).toStringAsFixed(1);

                return Padding(
                  key: ValueKey(file.path),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF4F46E5)),
                      ),
                      title: Text(
                        fileName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        "$fileSize KB",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
                            onPressed: () => _removePdf(index),
                          ),
                          const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: selectedPdfs.length < 2 ? null : _showRenameDialog,
                  child: Text(
                    "Merge ${selectedPdfs.length} Files",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
