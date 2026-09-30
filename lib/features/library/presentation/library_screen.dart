import 'package:flutter/material.dart';

/// Placeholder until task 2.6 adds the document list and import flow.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No documents yet.\nImport a course PDF to get started.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
