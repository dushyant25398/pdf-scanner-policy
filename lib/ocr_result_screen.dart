import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class OcrResultScreen extends StatelessWidget {
  final String text;
  const OcrResultScreen({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OCR Result"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Text copied to clipboard! 📋")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(text),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(
          text.isEmpty ? "No text detected." : text,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}
