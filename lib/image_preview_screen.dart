import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/widgets.dart' as pw;
import 'services/storage_service.dart';
import 'package:path_provider/path_provider.dart';

class ImagePreviewScreen extends StatefulWidget {
  final List<XFile> images;

  const ImagePreviewScreen({super.key, required this.images});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late List<XFile> selectedImages;

  @override
  void initState() {
    super.initState();
    selectedImages = List.from(widget.images);
  }

  void _removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
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
      });
    }
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Preview Images", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: selectedImages.isEmpty
                    ? const Center(
                        child: Text(
                          "No images selected",
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: selectedImages.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemBuilder: (context, index) {
                          final image = selectedImages[index];

                          return GestureDetector(
                            onTap: () => _cropImage(index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(File(image.path), fit: BoxFit.cover),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            color: Colors.black.withValues(alpha: 0.5),
                                            child: const Icon(Icons.close, size: 18, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: const Icon(Icons.crop, color: Colors.white70, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _pickMoreImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text("ADD IMAGES", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: selectedImages.isEmpty ? null : _showRenameDialog,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text("CREATE PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
