import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'widgets/scale_button.dart';
import 'dart:ui';

class CompressionScreen extends StatefulWidget {
  const CompressionScreen({super.key});

  @override
  State<CompressionScreen> createState() => _CompressionScreenState();
}

class _CompressionScreenState extends State<CompressionScreen> {
  File? _selectedFile;
  bool _isPdf = false;
  bool _isCompressing = false;
  String _originalSize = "0 KB";
  String _compressedSize = "0 KB";
  double _quality = 0.5; // 0.0 to 1.0 (Low to High)
  File? _compressedFile;
  final TextEditingController _targetSizeController = TextEditingController();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _selectedFile = file;
        _isPdf = file.path.toLowerCase().endsWith('.pdf');
        _originalSize = _getFileSizeString(file.lengthSync());
        _compressedFile = null;
        _compressedSize = "0 KB";
      });
    }
  }

  String _getFileSizeString(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> _compressImage() async {
    if (_selectedFile == null) return;
    setState(() => _isCompressing = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      int quality = (_quality * 100).toInt();
      if (quality < 1) quality = 1;

      var result = await FlutterImageCompress.compressAndGetFile(
        _selectedFile!.absolute.path,
        targetPath,
        quality: quality,
      );

      if (result != null) {
        setState(() {
          _compressedFile = File(result.path);
          _compressedSize = _getFileSizeString(_compressedFile!.lengthSync());
        });
      }
    } catch (e) {
      debugPrint("Compression error: $e");
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  Future<void> _compressPdf() async {
    if (_selectedFile == null) return;
    setState(() => _isCompressing = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
      
      final tempDir = await getTemporaryDirectory();
      final targetPath = "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf";
      
      sf.PdfCompressionOptions options = sf.PdfCompressionOptions();
      options.compressImages = true;
      options.imageQuality = (_quality * 100).toInt().clamp(10, 100);
      options.optimizeFonts = true;
      options.removeMetadata = _quality < 0.5;

      final List<int> compressedBytes = await document.save(compressionOptions: options);
      _compressedFile = File(targetPath);
      await _compressedFile!.writeAsBytes(compressedBytes);
      document.dispose();

      setState(() {
        _compressedSize = _getFileSizeString(_compressedFile!.lengthSync());
      });
    } catch (e) {
      debugPrint("PDF Compression error: $e");
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  Future<void> _convertToPdfAndShare() async {
    if (_compressedFile == null || _isPdf) return;
    
    setState(() => _isCompressing = true);
    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(_compressedFile!.readAsBytesSync());
      pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Image(image))));
      
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint("Conversion error: $e");
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compression Lab"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBentoHeader(),
            const SizedBox(height: 24),
            if (_selectedFile == null)
              _buildPickerPlaceholder()
            else
              _buildFileDetails(),
            
            if (_selectedFile != null) ...[
              const SizedBox(height: 32),
              _buildCompressionControls(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBentoHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.compress_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Smart Optimizer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Reduce file size while keeping quality",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerPlaceholder() {
    return ScaleButton(
      onTap: _pickFile,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text("Select PDF or Image", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_isPdf ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: _isPdf ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _selectedFile!.path.split(Platform.pathSeparator).last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(onPressed: _pickFile, icon: const Icon(Icons.edit, size: 18)),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSizeInfo("Original", _originalSize, Colors.grey),
              const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
              _buildSizeInfo("Compressed", _compressedSize, const Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSizeInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildCompressionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Optimization Quality", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQualityChip("Low", 0.2),
            _buildQualityChip("Medium", 0.5),
            _buildQualityChip("High", 0.8),
          ],
        ),
        const SizedBox(height: 24),
        if (_isPdf) ...[
          const Text("Target Size (Approximate)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _targetSizeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: "e.g., 2 (for 2MB)",
              suffixText: "MB",
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQualityChip(String label, double val) {
    bool isSelected = _quality == val;
    return ScaleButton(
      onTap: () => setState(() => _quality = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ScaleButton(
          onTap: _isPdf ? _compressPdf : _compressImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: _isCompressing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Compress Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
        if (_compressedFile != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ScaleButton(
                  onTap: () => Share.shareXFiles([XFile(_compressedFile!.path)]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text("Share File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              if (!_isPdf) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ScaleButton(
                    onTap: _convertToPdfAndShare,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text("To PDF & Share", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
