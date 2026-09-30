import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/app.dart';
import 'package:offline_study_assistant/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('app starts on the library screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });
}
