import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class OcrResultScreen extends StatelessWidget {
  final String text;

  const OcrResultScreen({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Extracted Text"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Copied to clipboard 📋")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(text);
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            text.isEmpty ? "No text found in the image." : text,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
