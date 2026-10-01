import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/app.dart';
import 'package:offline_study_assistant/app/providers.dart';
import 'package:offline_study_assistant/core/ai/model_manager.dart';
import 'package:offline_study_assistant/core/db/app_database.dart';
import 'package:offline_study_assistant/features/library/presentation/library_screen.dart';
import 'package:offline_study_assistant/features/model_setup/presentation/model_setup_screen.dart';

import '../helpers/fake_model_manager.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, FakeModelManager manager) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelsDirectoryProvider.overrideWithValue('/models'),
          appSettingsProvider.overrideWithValue(FakeAppSettings()),
          modelManagerProvider.overrideWithValue(manager),
          documentStoreProvider.overrideWithValue(db),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the library when the model is ready', (tester) async {
    await pumpApp(tester, FakeModelManager());

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.textContaining('No documents yet'), findsOneWidget);
  });

  testWidgets('shows the setup screen until the model is ready', (
    tester,
  ) async {
    final manager = FakeModelManager(
      const ModelNotDownloaded(totalBytes: 584417280),
    );
    await pumpApp(tester, manager);

    expect(find.byType(ModelSetupScreen), findsOneWidget);
    expect(find.byType(LibraryScreen), findsNothing);

    manager.emit(const ModelReady('/models/model.litertlm'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(ModelSetupScreen), findsNothing);
  });
}
