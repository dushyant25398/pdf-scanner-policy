import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'signature_screen.dart';
import 'services/storage_service.dart';

class EditElement {
  final String id;
  Offset position;
  double size;
  String? text;
  Uint8List? signature;
  bool isBold;

  EditElement({
    required this.id,
    required this.position,
    this.size = 100,
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
  bool isPdf = false;
  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    isPdf = widget.imageFile.path.toLowerCase().endsWith('.pdf');
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
                      position: const Offset(100, 100),
                      size: 24,
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
          position: const Offset(100, 200),
          size: 150,
          signature: result,
        ));
      });
    }
  }

  void _duplicateElement(EditElement e) {
    setState(() {
      elements.add(EditElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        position: e.position + const Offset(20, 20),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdf = pw.Document();
      final baseImageBytes = await widget.imageFile.readAsBytes();
      final baseImage = pw.MemoryImage(baseImageBytes);

      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat.undefined,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Image(baseImage),
                ...elements.map((e) {
                  if (e.signature != null) {
                    return pw.Positioned(
                      left: e.position.dx,
                      top: e.position.dy,
                      child: pw.Image(pw.MemoryImage(e.signature!), width: e.size),
                    );
                  } else {
                    return pw.Positioned(
                      left: e.position.dx,
                      top: e.position.dy,
                      child: pw.Text(
                        e.text ?? "",
                        style: pw.TextStyle(
                          fontSize: e.size,
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
        // NO FIRESTORE CALLS HERE - LOCAL SAVE ONLY
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

  Widget _buildElement(EditElement e) {
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            e.position += details.delta;
          });
        },
        onLongPress: () => _showElementOptions(e),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1),
          ),
          child: GestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                e.size = (e.size * details.scale).clamp(10, 500);
              });
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: e.signature != null
                      ? Image.memory(e.signature!, width: e.size)
                      : Text(
                          e.text ?? "",
                          style: TextStyle(
                            fontSize: e.size,
                            fontWeight: e.isBold ? FontWeight.bold : FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.copy, size: 14, color: Colors.blue.withValues(alpha: 0.5)),
                ),
              ],
            ),
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
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                color: Colors.white,
                child: Stack(
                  key: _stackKey,
                  children: [
                    Center(child: Image.file(widget.imageFile, fit: BoxFit.contain)),
                    ...elements.map((e) => _buildElement(e)).toList(),
                  ],
                ),
              ),
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
                  _actionButton(Icons.delete_outline, "Clear All", () => setState(() => elements.clear())),
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
