import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'signature_screen.dart';
import 'services/storage_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:path_provider/path_provider.dart';

class EditElement {
  final String id;
  Offset position; // Normalized 0.0 to 1.0 relative to image
  double size;     // Normalized relative to image width
  String? text;
  Uint8List? signature;
  bool isBold;

  EditElement({
    required this.id,
    required this.position,
    this.size = 0.2,
    this.text,
    this.signature,
    this.isBold = false,
  });
}

class EditPdfScreen extends StatefulWidget {
  final File imageFile;

  const EditPdfScreen({super.key, required this.imageFile});

  @override
  State<EditPdfScreen> createState() => _EditPdfScreenState();
}

class _EditPdfScreenState extends State<EditPdfScreen> {
  List<EditElement> elements = [];
  File? _displayImage;
  bool _isRendering = false;
  Size? _imageSize; // Actual image pixels

  @override
  void initState() {
    super.initState();
    _prepareImage();
  }

  Future<void> _prepareImage() async {
    if (widget.imageFile.path.toLowerCase().endsWith('.pdf')) {
      setState(() => _isRendering = true);
      try {
        final document = await pdfx.PdfDocument.openFile(widget.imageFile.path);
        final page = await document.getPage(1);
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 100,
        );

        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/edit_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(pageImage!.bytes);

        final decoded = await decodeImageFromList(pageImage.bytes);
        
        setState(() {
          _displayImage = tempFile;
          _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
          _isRendering = false;
        });
        await page.close();
        await document.close();
      } catch (e) {
        debugPrint("Error rendering PDF: $e");
        setState(() => _isRendering = false);
      }
    } else {
      final bytes = await widget.imageFile.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      setState(() {
        _displayImage = widget.imageFile;
        _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      });
    }
  }

  void _addText() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text("Add Text"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "Enter text here"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    elements.add(EditElement(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      position: const Offset(0.4, 0.4),
                      size: 0.1, // 10% of image width
                      text: controller.text,
                    ));
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSignature() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    );

    if (result != null && result is Uint8List) {
      setState(() {
        elements.add(EditElement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          position: const Offset(0.4, 0.6),
          size: 0.3, // 30% of image width
          signature: result,
        ));
      });
    }
  }

  void _duplicateElement(EditElement e) {
    setState(() {
      elements.add(EditElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        position: e.position + const Offset(0.05, 0.05),
        size: e.size,
        text: e.text,
        signature: e.signature,
        isBold: e.isBold,
      ));
    });
  }

  void _showElementOptions(EditElement e) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text("Duplicate"),
            onTap: () {
              Navigator.pop(context);
              _duplicateElement(e);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text("Delete", style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              setState(() => elements.remove(e));
            },
          ),
          if (e.text != null)
            ListTile(
              leading: const Icon(Icons.format_bold),
              title: const Text("Toggle Bold"),
              onTap: () {
                Navigator.pop(context);
                setState(() => e.isBold = !e.isBold);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveEditedPdf() async {
    if (_displayImage == null || _imageSize == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      final baseImageBytes = await _displayImage!.readAsBytes();
      final baseImage = pw.MemoryImage(baseImageBytes);

      final pageWidth = _imageSize!.width;
      final pageHeight = _imageSize!.height;

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Image(baseImage),
                ...elements.map((e) {
                  final posX = e.position.dx * pageWidth;
                  final posY = e.position.dy * pageHeight;
                  final size = e.size * pageWidth;

                  if (e.signature != null) {
                    return pw.Positioned(
                      left: posX,
                      top: posY,
                      child: pw.Image(pw.MemoryImage(e.signature!), width: size),
                    );
                  } else {
                    return pw.Positioned(
                      left: posX,
                      top: posY,
                      child: pw.Text(
                        e.text ?? "",
                        style: pw.TextStyle(
                          fontSize: size,
                          fontWeight: e.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        ),
                      ),
                    );
                  }
                }),
              ],
            );
          },
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      String? fileName = await showDialog<String>(
        context: context,
        builder: (context) {
          TextEditingController controller = TextEditingController(
              text: "edited_${DateTime.now().millisecondsSinceEpoch}");
          return AlertDialog(
            title: const Text("Save PDF"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "File name"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text("Save")),
            ],
          );
        },
      );

      if (fileName != null && fileName.trim().isNotEmpty) {
        final folder = await StorageService.getPdfDirectory();
        final file = File("${folder.path}/$fileName.pdf");
        await file.writeAsBytes(await pdf.save());
        if (mounted) {
          Navigator.pop(context, file);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Edited PDF Saved ✅")),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error saving edited PDF: $e");
    }
  }

  Widget _buildElement(EditElement e, double renderedWidth, double renderedHeight) {
    return Positioned(
      left: e.position.dx * renderedWidth,
      top: e.position.dy * renderedHeight,
      child: GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            // Movement
            double dx = e.position.dx + (details.focalPointDelta.dx / renderedWidth);
            double dy = e.position.dy + (details.focalPointDelta.dy / renderedHeight);
            e.position = Offset(dx.clamp(0.0, 1.0), dy.clamp(0.0, 1.0));
            
            // Scaling
            if (details.scale != 1.0) {
              e.size = (e.size * details.scale).clamp(0.01, 1.0);
            }
          });
        },
        onLongPress: () => _showElementOptions(e),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              e.signature != null
                  ? Image.memory(e.signature!, width: e.size * renderedWidth)
                  : Text(
                      e.text ?? "",
                      style: TextStyle(
                        fontSize: e.size * renderedWidth,
                        fontWeight: e.isBold ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
              Positioned(
                top: -15,
                right: -15,
                child: GestureDetector(
                  onTap: () => _duplicateElement(e),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.copy, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("Edit & Sign"),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveEditedPdf),
        ],
      ),
      body: _isRendering
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_displayImage == null || _imageSize == null) {
                        return const Center(child: Text("Loading image...", style: TextStyle(color: Colors.white)));
                      }

                      // Calculate fit size
                      double scale = Math.min(
                        constraints.maxWidth / _imageSize!.width,
                        constraints.maxHeight / _imageSize!.height,
                      );
                      double renderedWidth = _imageSize!.width * scale;
                      double renderedHeight = _imageSize!.height * scale;

                      return Center(
                        child: Container(
                          width: renderedWidth,
                          height: renderedHeight,
                          color: Colors.white,
                          child: Stack(
                            children: [
                              Image.file(_displayImage!, fit: BoxFit.fill),
                              ...elements.map((e) => _buildElement(e, renderedWidth, renderedHeight)).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  color: Colors.white,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionButton(Icons.text_fields, "Text", _addText),
                        _actionButton(Icons.gesture, "Signature", _addSignature),
                        _actionButton(
                            Icons.delete_outline,
                            "Clear All",
                            () => setState(() => elements.clear())),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }
}

class Math {
  static double min(double a, double b) => a < b ? a : b;
}

