import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/features/benchmark/presentation/llm_benchmark_screen.dart';
import 'package:offline_study_assistant/features/benchmark/presentation/llm_debug_screen.dart';
import 'package:offline_study_assistant/features/library/presentation/library_screen.dart';
import 'package:offline_study_assistant/features/model_setup/presentation/model_setup_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const library = '/';
  static const modelSetup = '/setup';
  static const llmDebug = '/debug/llm';
  static const llmBenchmark = '/debug/llm-benchmark';
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  bool modelReady() => ref.read(currentModelStateProvider) is ModelReady;

  // A ValueNotifier only notifies on change: the redirect re-runs when
  // readiness flips, not on every progress tick.
  final readiness = ValueNotifier(modelReady());
  ref
    ..listen(
      currentModelStateProvider,
      (_, state) => readiness.value = state is ModelReady,
    )
    ..onDispose(readiness.dispose);

  return GoRouter(
    initialLocation: AppRoutes.library,
    refreshListenable: readiness,
    redirect: (context, state) {
      final atSetup = state.matchedLocation == AppRoutes.modelSetup;
      if (!modelReady()) return atSetup ? null : AppRoutes.modelSetup;
      return atSetup ? AppRoutes.library : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.library,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.modelSetup,
        builder: (context, state) => const ModelSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.llmDebug,
        builder: (context, state) => const LlmDebugScreen(),
      ),
      GoRoute(
        path: AppRoutes.llmBenchmark,
        builder: (context, state) => const LlmBenchmarkScreen(),
      ),
    ],
  );
}
