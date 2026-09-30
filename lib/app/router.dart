import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/features/benchmark/presentation/llm_debug_screen.dart';
import 'package:offline_study_assistant/features/library/presentation/library_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const library = '/';
  static const llmDebug = '/debug/llm';
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.llmDebug,
        builder: (context, state) => const LlmDebugScreen(),
      ),
    ],
  );
}
