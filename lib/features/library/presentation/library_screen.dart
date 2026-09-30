import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/router.dart';

/// Placeholder until task 2.6 adds the document list and import flow.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'LLM debug',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => context.push(AppRoutes.llmDebug),
          ),
        ],
      ),
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
