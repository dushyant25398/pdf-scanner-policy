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
import 'package:google_fonts/google_fonts.dart';

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
  String _estimatedSize = "0 KB";
  double _quality = 0.5; // 0.0 to 1.0 (Low to High)
  File? _compressedFile;
  final TextEditingController _targetSizeController = TextEditingController();
  bool _isCustomMode = false;

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
        _updateEstimatedSize();
      });
    }
  }

  String _getFileSizeString(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  void _updateEstimatedSize() {
    if (_selectedFile == null) return;
    int originalBytes = _selectedFile!.lengthSync();
    double ratio;
    if (_isCustomMode) {
      double? targetMb = double.tryParse(_targetSizeController.text);
      if (targetMb != null) {
        _estimatedSize = "${targetMb.toStringAsFixed(2)} MB";
        return;
      }
      ratio = 0.5; // default for custom if empty
    } else {
      // Very rough estimates for UI feedback
      if (_quality <= 0.2) ratio = 0.2;
      else if (_quality <= 0.5) ratio = 0.5;
      else ratio = 0.8;
    }
    _estimatedSize = _getFileSizeString((originalBytes * ratio).toInt());
  }

  Future<void> _compressNow() async {
    if (_selectedFile == null) return;
    setState(() => _isCompressing = true);

    try {
      if (_isCustomMode && _targetSizeController.text.isNotEmpty) {
        // Custom target size logic (simplified for now as precise target size compression is complex)
        double targetMb = double.tryParse(_targetSizeController.text) ?? 1.0;
        int targetBytes = (targetMb * 1024 * 1024).toInt();
        int currentBytes = _selectedFile!.lengthSync();
        _quality = (targetBytes / currentBytes).clamp(0.1, 0.9);
      }

      if (_isPdf) {
        await _compressPdf();
      } else {
        await _compressImage();
      }
    } catch (e) {
      debugPrint("Compression error: $e");
    } finally {
      setState(() => _isCompressing = false);
    }
  }

  Future<void> _compressImage() async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
    
    int qualityInt = (_quality * 100).toInt();
    if (qualityInt < 1) qualityInt = 1;

    var result = await FlutterImageCompress.compressAndGetFile(
      _selectedFile!.absolute.path,
      targetPath,
      quality: qualityInt,
    );

    if (result != null) {
      setState(() {
        _compressedFile = File(result.path);
        _compressedSize = _getFileSizeString(_compressedFile!.lengthSync());
      });
    }
  }

  Future<void> _compressPdf() async {
    final bytes = await _selectedFile!.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    
    // Configure compression level
    document.compressionLevel = _quality <= 0.3 
        ? sf.PdfCompressionLevel.best 
        : (_quality <= 0.6 ? sf.PdfCompressionLevel.normal : sf.PdfCompressionLevel.belowNormal);
    
    final tempDir = await getTemporaryDirectory();
    final targetPath = "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf";
    
    final List<int> compressedBytes = await document.save();
    _compressedFile = File(targetPath);
    await _compressedFile!.writeAsBytes(compressedBytes);
    document.dispose();

    setState(() {
      _compressedSize = _getFileSizeString(_compressedFile!.lengthSync());
    });
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

  Future<void> _downloadFile() async {
    if (_compressedFile == null) return;
    try {
      final fileName = _compressedFile!.path.split(Platform.pathSeparator).last;
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Use a more robust way to get downloads folder for Android
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            // Fallback to app-specific external directory if standard Download is inaccessible
            downloadsDir = externalDir;
          }
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir != null) {
        final newPath = "${downloadsDir.path}/$fileName";
        await _compressedFile!.copy(newPath);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to Downloads: $fileName")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compression Lab"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Smart Optimizer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Reduce file size while keeping quality",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
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
              _buildSizeInfo(_compressedFile == null ? "Estimated" : "Compressed", _compressedFile == null ? _estimatedSize : _compressedSize, const Color(0xFF4F46E5)),
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildQualityChip("Low", 0.2),
            _buildQualityChip("Medium", 0.5),
            _buildQualityChip("High", 0.8),
            _buildCustomChip(),
          ],
        ),
        if (_isCustomMode) ...[
          const SizedBox(height: 24),
          const Text("Enter Target Size", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _targetSizeController,
            keyboardType: TextInputType.number,
            onChanged: (val) => setState(() => _updateEstimatedSize()),
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
    bool isSelected = !_isCustomMode && _quality == val;
    return ScaleButton(
      onTap: () {
        setState(() {
          _isCustomMode = false;
          _quality = val;
          _updateEstimatedSize();
        });
      },
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

  Widget _buildCustomChip() {
    return ScaleButton(
      onTap: () {
        setState(() {
          _isCustomMode = true;
          _updateEstimatedSize();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _isCustomMode ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "Custom",
          style: TextStyle(
            color: _isCustomMode ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
          onTap: _compressNow,
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: Icons.share_rounded,
                  label: "Share",
                  color: const Color(0xFF10B981),
                  onTap: () => Share.shareXFiles([XFile(_compressedFile!.path)]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionTile(
                  icon: Icons.download_rounded,
                  label: "Save",
                  color: const Color(0xFF3B82F6),
                  onTap: _downloadFile,
                ),
              ),
            ],
          ),
          if (!_isPdf) ...[
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.picture_as_pdf_rounded,
              label: "Convert to PDF & Share",
              color: const Color(0xFFF59E0B),
              onTap: _convertToPdfAndShare,
              isFullWidth: true,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
