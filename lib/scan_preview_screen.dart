import 'dart:io';
import 'package:flutter/material.dart';

enum ScanFilter { document, natural, gray, eco }

class ScanPreviewScreen extends StatefulWidget {
  final List<String> allImagePaths;
  final int initialPage;

  const ScanPreviewScreen({
    super.key,
    required this.allImagePaths,
    this.initialPage = 0,
  });

  @override
  State<ScanPreviewScreen> createState() => _ScanPreviewScreenState();
}

class _ScanPreviewScreenState extends State<ScanPreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  ScanFilter selectedFilter = ScanFilter.document; // Default to Document filter
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

  List<double> _getFilterMatrix(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.document:
        // High contrast grayscale (B/W clean)
        return [
          1.5, 1.5, 1.5, 0, -100,
          1.5, 1.5, 1.5, 0, -100,
          1.5, 1.5, 1.5, 0, -100,
          0, 0, 0, 1, 0,
        ];
      case ScanFilter.gray:
        return [
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case ScanFilter.eco:
        return [
          1.2, 0, 0, 0, 10,
          0, 1.2, 0, 0, 10,
          0, 0, 1.2, 0, 10,
          0, 0, 0, 1, 0,
        ];
      case ScanFilter.natural:
      default:
        return [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Page ${_currentIndex + 1} / ${widget.allImagePaths.length}", 
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: () => setState(() => rotationTurns = (rotationTurns + 1) % 4),
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
                  itemCount: widget.allImagePaths.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: rotationTurns,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(_getFilterMatrix(selectedFilter)),
                            child: Image.file(
                              File(widget.allImagePaths[index]),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildFilterToolbar(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ScanFilter.values.map((filter) {
          bool isSelected = selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Text(
                filter.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
           Row(
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
                  label: const Text("ADD MORE"),
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
                  onPressed: () => Navigator.pop(context, {
                    'action': 'save_pdf',
                    'filter': selectedFilter,
                  }),
                  icon: const Icon(Icons.check_circle),
                  label: const Text("SAVE PDF"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
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
        ],
      ),
    );
  }
}
