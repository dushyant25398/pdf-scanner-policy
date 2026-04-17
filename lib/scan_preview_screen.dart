import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

class ScanPreviewScreen extends StatefulWidget {
  final List<Uint8List> allImages;
  final int initialPage;

  const ScanPreviewScreen({
    super.key,
    required this.allImages,
    this.initialPage = 0,
  });

  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool isGrayscale = false;
  double contrast = 1.0;
  int rotationTurns = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _applyFilter(String type) {
    setState(() {
      if (type == "Natural") {
        isGrayscale = false;
        contrast = 1.0;
      } else if (type == "Gray") {
        isGrayscale = true;
        contrast = 1.0;
      } else if (type == "Eco") {
        isGrayscale = true;
        contrast = 1.5;
      }
    });
  }

  void _rotate() {
    setState(() {
      rotationTurns = (rotationTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Page ${_currentIndex + 1} / ${widget.allImages.length}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: _rotate,
          ),
        ],
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
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.allImages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                      child: InteractiveViewer(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: rotationTurns,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                isGrayscale
                                    ? [
                                        0.2126 * contrast, 0.7152 * contrast, 0.0722 * contrast, 0, 0,
                                        0.2126 * contrast, 0.7152 * contrast, 0.0722 * contrast, 0, 0,
                                        0.2126 * contrast, 0.7152 * contrast, 0.0722 * contrast, 0, 0,
                                        0, 0, 0, 1, 0,
                                      ]
                                    : [
                                        contrast, 0, 0, 0, 0,
                                        0, contrast, 0, 0, 0,
                                        0, 0, contrast, 0, 0,
                                        0, 0, 0, 1, 0,
                                      ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.memory(
                                  widget.allImages[index],
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildFilterToolbar(),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterButton("Natural"),
          _filterButton("Gray"),
          _filterButton("Eco"),
        ],
      ),
    );
  }

  Widget _filterButton(String label) {
    bool isSelected = (label == "Natural" && !isGrayscale) ||
        (label == "Gray" && isGrayscale && contrast == 1.0) ||
        (label == "Eco" && isGrayscale && contrast > 1.0);

    return GestureDetector(
      onTap: () => _applyFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            "${widget.allImages.length} page(s) added",
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
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
                  onPressed: () => Navigator.pop(context, 'add_more'),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text("ADD MORE", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  onPressed: () {
                    Navigator.pop(context, 'save_pdf');
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text("CREATE PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              Navigator.pop(context, 'ocr_${_currentIndex}');
            },
            icon: const Icon(Icons.text_snippet),
            label: const Text("EXTRACT TEXT (OCR)", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
