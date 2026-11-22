import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class _DataSource extends CalendarDataSource {
  _DataSource(List<Appointment> source) {
    appointments = source;
  }
}

/// GoHost (go-helmmetry#4736): data source đổi rồi calendar bị gỡ ngay trong
/// cùng frame → callback sau frame không được gọi `setState` sau dispose.
void main() {
  for (final CalendarView view in <CalendarView>[
    CalendarView.day,
    CalendarView.timelineDay,
    CalendarView.timelineMonth,
  ]) {
    testWidgets('gỡ calendar ngay sau khi data source đổi ($view)', (
      WidgetTester tester,
    ) async {
      final DateTime start = DateTime.now();
      final _DataSource source = _DataSource(<Appointment>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: SfCalendar(view: view, dataSource: source),
        ),
      );

      final Appointment added = Appointment(
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
      );
      source.appointments!.add(added);
      source.notifyListeners(CalendarDataSourceAction.add, <Appointment>[
        added,
      ]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
