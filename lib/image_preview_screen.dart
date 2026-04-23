import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'services/storage_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:reorderables/reorderables.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/scale_button.dart';

class ImagePreviewScreen extends StatefulWidget {
  final List<XFile> images;

  const ImagePreviewScreen({super.key, required this.images});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late List<XFile> selectedImages;
  late List<XFile> originalImages;

  @override
  void initState() {
    super.initState();
    selectedImages = List.from(widget.images);
    originalImages = List.from(widget.images);
  }

  void _removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
      originalImages.removeAt(index);
    });
    if (selectedImages.isEmpty) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickMoreImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        selectedImages.addAll(images);
        originalImages.addAll(images);
      });
    }
  }

  Future<void> _cropImage(int index) async {
    final image = selectedImages[index];
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        selectedImages[index] = XFile(croppedFile.path);
        // We don't update originalImages here because we want to be able to revert to the non-filtered version
        // but crop is usually considered a "hard" edit. 
        // For simplicity, we'll let users keep the cropped version as the new base.
        originalImages[index] = XFile(croppedFile.path);
      });
    }
  }

  Future<void> _applyFilter(int index, String filterType) async {
    if (filterType == 'original') {
      setState(() {
        selectedImages[index] = originalImages[index];
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await File(originalImages[index].path).readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image != null) {
        if (filterType == 'grayscale') {
          image = img.grayscale(image);
        } else if (filterType == 'magic') {
          // Enhance colors for document scanning
          image = img.adjustColor(image, contrast: 1.2, brightness: 1.1);
        } else if (filterType == 'bw') {
          image = img.grayscale(image);
          image = img.contrast(image, contrast: 2.0);
        }

        final tempDir = await getTemporaryDirectory();
        final filteredFile = File('${tempDir.path}/filter_${filterType}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await filteredFile.writeAsBytes(img.encodeJpg(image, quality: 90));

        setState(() {
          selectedImages[index] = XFile(filteredFile.path);
        });
      }
    } catch (e) {
      debugPrint("Filter error: $e");
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text("Image Options", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.crop_rounded),
              title: const Text("Crop Image"),
              onTap: () {
                Navigator.pop(context);
                _cropImage(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high_rounded),
              title: const Text("Apply Filters"),
              onTap: () {
                Navigator.pop(context);
                _showFilterOptions(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text("Remove", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeImage(index);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enhance Image", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _filterButton(index, "Original", "original", Icons.refresh),
                  _filterButton(index, "Magic", "magic", Icons.auto_awesome),
                  _filterButton(index, "Grayscale", "grayscale", Icons.filter_b_and_w),
                  _filterButton(index, "B&W", "bw", Icons.exposure),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(int index, String label, String type, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _applyFilter(index, type);
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    TextEditingController controller = TextEditingController(
      text: "import_${DateTime.now().millisecondsSinceEpoch}",
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter PDF Name"),
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
              _createPdf(controller.text.trim());
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _createPdf(String fileName) async {
    if (selectedImages.isEmpty || fileName.isEmpty) return;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final pdf = pw.Document();

      for (var img in selectedImages) {
        final bytes = await img.readAsBytes();
        final image = pw.MemoryImage(bytes);

        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(child: pw.Image(image)),
          ),
        );
      }

      final folder = await StorageService.getPdfDirectory();
      final file = File("${folder.path}/$fileName.pdf");

      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF created successfully ✅")),
        );
        Navigator.pop(context, file); // Return to home with file
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating PDF: $e ❌")),
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
          "Review Pages",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: selectedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text("No images selected", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ReorderableWrap(
                    spacing: 12,
                    runSpacing: 12,
                    padding: const EdgeInsets.all(20),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final image = selectedImages.removeAt(oldIndex);
                        selectedImages.insert(newIndex, image);
                        final original = originalImages.removeAt(oldIndex);
                        originalImages.insert(newIndex, original);
                      });
                    },
                    children: List.generate(selectedImages.length, (index) {
                      final image = selectedImages[index];

                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 52) / 2,
                        child: ScaleButton(
                          onTap: () => _showImageOptions(index),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: Image.file(File(image.path), fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                        ),
                                      ),
                                      child: Text(
                                        "Page ${index + 1}",
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _pickMoreImages,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: Text("ADD", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: selectedImages.isEmpty ? null : _showRenameDialog,
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: Text("GENERATE", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
