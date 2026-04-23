import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/scale_button.dart';

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

class _ScanPreviewScreenState extends State<ScanPreviewScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  ScanFilter selectedFilter = ScanFilter.document; // Default to Document filter
  int rotationTurns = 0;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scanController.dispose();
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
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Review ${_currentIndex + 1} / ${widget.allImagePaths.length}",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            onPressed: () => setState(() => rotationTurns = (rotationTurns + 1) % 4),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.allImagePaths.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            RotatedBox(
                              quarterTurns: rotationTurns,
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(_getFilterMatrix(selectedFilter)),
                                child: Image.file(
                                  File(widget.allImagePaths[index]),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Smart Scanning Laser Line
                            AnimatedBuilder(
                              animation: _scanAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: MediaQuery.of(context).size.height * 0.7 * _scanAnimation.value,
                                  left: 0,
                                  right: 0,
                                  child: Opacity(
                                    opacity: 0.8,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blueAccent.withValues(alpha: 0),
                                            Colors.blueAccent,
                                            Colors.blueAccent.withValues(alpha: 0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent.withValues(alpha: 0.6),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterToolbar(),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: ScanFilter.values.length,
        itemBuilder: (context, index) {
          final filter = ScanFilter.values[index];
          bool isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                filter.name[0].toUpperCase() + filter.name.substring(1),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              onSelected: (val) => setState(() => selectedFilter = filter),
              selectedColor: const Color(0xFF4F46E5),
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ScaleButton(
                  onTap: () => Navigator.pop(context, 'add_more'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF4F46E5)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        "ADD PAGE",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ScaleButton(
                  onTap: () => Navigator.pop(context, {
                    'action': 'save_pdf',
                    'filter': selectedFilter,
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        "SAVE PDF",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ScaleButton(
            onTap: () => Navigator.pop(context, 'ocr_${_currentIndex}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.text_snippet_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "EXTRACT TEXT (OCR)",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD97706),
                      fontSize: 14,
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
