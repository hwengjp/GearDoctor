import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gear_doctor/widgets/widgets.dart';

void main() {
  test('date picker first year leaves enough years to scroll to the selected one', () {
    expect(appDatePickerFirstDate(DateTime(2026, 8, 23)).year, 2000);
    expect(appDatePickerFirstDate(DateTime(2010, 1, 1)).year, 1993);
  });

  testWidgets('year grid shows the selected year without starting at 2010', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showAppDatePicker(
                    context: context,
                    initialDate: DateTime(2025, 7, 17),
                    lastDate: DateTime(2026, 8, 23),
                    currentDate: DateTime(2026, 8, 23),
                  );
                },
                child: const Text('pick'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('July 2025'));
    await tester.pumpAndSettle();

    expect(find.text('2025').hitTestable(), findsWidgets);
    expect(find.text('2026').hitTestable(), findsOneWidget);
    expect(find.text('2000').hitTestable(), findsNothing);
  });
}
