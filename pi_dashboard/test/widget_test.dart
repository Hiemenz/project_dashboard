import 'package:flutter_test/flutter_test.dart';

import 'package:pi_dashboard/main.dart';

void main() {
  testWidgets('Dashboard shows empty state with no hosts', (tester) async {
    await tester.pumpWidget(const PiDashboardApp());
    await tester.pumpAndSettle();

    expect(find.text('No Pis added yet. Add one to start monitoring.'),
        findsOneWidget);
    expect(find.text('Add Pi'), findsOneWidget);
  });
}
