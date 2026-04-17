import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Signature"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_controller.isNotEmpty) {
                final Uint8List? data = await _controller.toPngBytes();
                if (mounted) {
                  Navigator.pop(context, data);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _controller.clear(),
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                const Text("Sign above", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
