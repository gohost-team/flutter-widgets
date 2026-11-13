import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

/// Hàng 1 cao 68/46 lần chiều cao chung (tỉ lệ thiết kế "Chưa xếp phòng").
const double _tallFactor = 68 / 46;
const int _tallIndex = 1;
const int _resourceCount = 6;

/// `bounds` mà builder nhận (toạ độ nội dung, hàng 0 ở y = 0). SfCalendar vẽ con
/// bằng `paintChild` theo offset nên `tester.getRect` không cho vị trí hàng thật.
final Map<String, Rect> _headerBounds = <String, Rect>{};
final Map<String, Rect> _cardBounds = <String, Rect>{};

class _DataSource extends CalendarDataSource<Appointment> {
  _DataSource(List<Appointment> source, List<CalendarResource> resources) {
    appointments = source;
    this.resources = resources;
  }
}

List<CalendarResource> _getMockResources() => List<CalendarResource>.generate(
  _resourceCount,
  (int i) => CalendarResource(id: 'r$i', displayName: 'Resource $i'),
);

/// Mỗi resource đúng 1 appointment trong ngày [day]; subject = id resource.
List<Appointment> _getMockAppointments(DateTime day) =>
    List<Appointment>.generate(
      _resourceCount,
      (int i) => Appointment(
        startTime: DateTime(day.year, day.month, day.day, 8),
        endTime: DateTime(day.year, day.month, day.day, 9),
        subject: 'r$i',
        resourceIds: <Object>['r$i'],
      ),
    );

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required CalendarView view,
  required DateTime day,
  ResourceItemHeightBuilder? heightBuilder,
  CalendarTapCallback? onTap,
}) async {
  _headerBounds.clear();
  _cardBounds.clear();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: SfCalendar(
              view: view,
              headerHeight: 0,
              initialDisplayDate: day,
              dataSource: _DataSource(
                _getMockAppointments(day),
                _getMockResources(),
              ),
              resourceViewSettings: const ResourceViewSettings(
                visibleResourceCount: 4,
              ),
              timeSlotViewSettings: const TimeSlotViewSettings(
                startHour: 8,
                endHour: 12,
                timeIntervalWidth: 60,
                // Như gohost-app: thẻ phủ cả chiều cao hàng.
                timelineAppointmentHeight: double.infinity,
              ),
              resourceItemHeightBuilder: heightBuilder,
              onTap: onTap,
              appointmentBuilder:
                  (BuildContext context, CalendarAppointmentDetails details) {
                    final Appointment appointment =
                        details.appointments.first as Appointment;
                    _cardBounds[appointment.subject] = details.bounds;
                    return Container(key: ValueKey<String>(appointment.subject));
                  },
              resourceViewHeaderBuilder:
                  (BuildContext context, ResourceViewHeaderDetails details) {
                    _headerBounds['${details.resource.id}'] = details.bounds;
                    return SizedBox.expand(
                      key: ValueKey<String>('h-${details.resource.id}'),
                    );
                  },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _header(WidgetTester tester, int i) => _headerBounds['r$i']!;

Rect _card(WidgetTester tester, int i) => _cardBounds['r$i']!;

/// Gốc toàn cục của vùng hàng (góc trên-trái hàng 0): mọi header đều bị
/// `getRect` báo cùng gốc này vì offset hàng chỉ nằm ở lúc vẽ.
Offset _rowsOrigin(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey<String>('h-r0'))).topLeft;

/// Toạ độ chạm toàn cục: cách panel resource [dx], tại y nội dung [y].
Offset _tapPoint(WidgetTester tester, double dx, double y) {
  final Rect panel = tester.getRect(find.byKey(const ValueKey<String>('h-r0')));
  return Offset(panel.right + dx, _rowsOrigin(tester).dy + y);
}

/// Chiều cao chung h = chiều cao header 'h-r0' của lượt dựng không có builder.
Future<double> _measureDefaultHeight(
  WidgetTester tester,
  CalendarView view,
  DateTime day,
) async {
  await _pumpCalendar(tester, view: view, day: day);
  return _header(tester, 0).height;
}

void main() {
  final DateTime day = DateTime(2026, 11, 10);

  for (final CalendarView view in <CalendarView>[
    CalendarView.timelineMonth,
    CalendarView.timelineDay,
  ]) {
    group('resourceItemHeightBuilder - $view', () {
      testWidgets('builder null: các hàng header cao bằng nhau và nối liền', (
        WidgetTester tester,
      ) async {
        await _pumpCalendar(tester, view: view, day: day);

        final double h = _header(tester, 0).height;
        expect(h, greaterThan(0));
        for (int i = 1; i < 4; i++) {
          expect(_header(tester, i).height, closeTo(h, 0.01), reason: 'r$i');
          expect(
            _header(tester, i).top,
            closeTo(_header(tester, 0).top + i * h, 0.01),
            reason: 'top r$i',
          );
        }
      });

      testWidgets('builder: hàng 1 cao 68/46·h, hàng 2 nối ngay dưới hàng 1', (
        WidgetTester tester,
      ) async {
        final double h = await _measureDefaultHeight(tester, view, day);
        final List<double> receivedDefaults = <double>[];
        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          heightBuilder:
              (CalendarResource resource, int index, double defaultHeight) {
                receivedDefaults.add(defaultHeight);
                return index == _tallIndex ? defaultHeight * _tallFactor : null;
              },
        );

        expect(receivedDefaults, isNotEmpty);
        expect(receivedDefaults.every((double d) => (d - h).abs() < 0.01), isTrue);

        final double tallHeight = h * _tallFactor;
        expect(_header(tester, 0).height, closeTo(h, 0.01));
        expect(_header(tester, 1).height, closeTo(tallHeight, 0.01));
        expect(_header(tester, 2).height, closeTo(h, 0.01));
        expect(_header(tester, 1).top, closeTo(_header(tester, 0).bottom, 0.01));
        expect(
          _header(tester, 2).top,
          closeTo(_header(tester, 1).top + tallHeight, 0.01),
        );
        expect(_header(tester, 3).top, closeTo(_header(tester, 2).bottom, 0.01));
      });

      testWidgets('builder: thẻ r2 nằm trong hàng r2, thẻ r0 không đổi', (
        WidgetTester tester,
      ) async {
        await _pumpCalendar(tester, view: view, day: day);
        final Rect cardR0Before = _card(tester, 0);

        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          heightBuilder: (CalendarResource r, int index, double d) =>
              index == _tallIndex ? d * _tallFactor : null,
        );

        final Rect row2 = _header(tester, 2);
        final Rect card2 = _card(tester, 2);
        expect(card2.top, greaterThanOrEqualTo(row2.top - 0.01));
        expect(card2.bottom, lessThanOrEqualTo(row2.bottom + 0.01));

        final Rect row1 = _header(tester, 1);
        final Rect card1 = _card(tester, 1);
        expect(card1.top, greaterThanOrEqualTo(row1.top - 0.01));
        expect(card1.bottom, lessThanOrEqualTo(row1.bottom + 0.01));

        final Rect row0 = _header(tester, 0);
        final Rect card0 = _card(tester, 0);
        expect(card0.height, closeTo(cardR0Before.height, 0.01));
        expect(card0.top - row0.top, closeTo(cardR0Before.top - row0.top, 0.01));
      });

      testWidgets('builder: thẻ r1 cao hơn thẻ r0 đúng phần chênh của hàng', (
        WidgetTester tester,
      ) async {
        final double h = await _measureDefaultHeight(tester, view, day);
        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          heightBuilder: (CalendarResource r, int index, double d) =>
              index == _tallIndex ? d * _tallFactor : null,
        );

        // Thẻ = slot hàng trừ padding cố định, nên chênh lệch chiều cao thẻ
        // phải đúng bằng chênh lệch chiều cao hàng.
        final double rowDiff = h * _tallFactor - h;
        expect(
          _card(tester, 1).height - _card(tester, 0).height,
          closeTo(rowDiff, 0.5),
        );
        expect(_card(tester, 2).height, closeTo(_card(tester, 0).height, 0.01));
      });

      testWidgets('builder: tap quanh ranh giới hàng r2/r3 trả đúng resource', (
        WidgetTester tester,
      ) async {
        final List<CalendarTapDetails> taps = <CalendarTapDetails>[];
        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          onTap: taps.add,
          heightBuilder: (CalendarResource r, int index, double d) =>
              index == _tallIndex ? d * _tallFactor : null,
        );

        final double boundary = _header(tester, 2).bottom;

        // Ô trống: cách panel resource xa hơn ô chứa appointment.
        await tester.tapAt(_tapPoint(tester, 200, boundary - 3));
        await tester.pump(const Duration(milliseconds: 400));
        expect(taps, isNotEmpty);
        expect(taps.last.resource?.id, 'r2');

        taps.clear();
        await tester.tapAt(_tapPoint(tester, 200, boundary + 3));
        await tester.pump(const Duration(milliseconds: 400));
        expect(taps, isNotEmpty);
        expect(taps.last.resource?.id, 'r3');
      });

      testWidgets('builder: tap giữa hàng cao r1 trả resource r1', (
        WidgetTester tester,
      ) async {
        final List<CalendarTapDetails> taps = <CalendarTapDetails>[];
        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          onTap: taps.add,
          heightBuilder: (CalendarResource r, int index, double d) =>
              index == _tallIndex ? d * _tallFactor : null,
        );

        final Rect row1 = _header(tester, 1);
        await tester.tapAt(_tapPoint(tester, 200, row1.bottom - 3));
        await tester.pump(const Duration(milliseconds: 400));
        expect(taps, isNotEmpty);
        expect(taps.last.resource?.id, 'r1');
      });
          testWidgets('builder: vùng cuộn dọc = tổng chiều cao các hàng', (
        WidgetTester tester,
      ) async {
        List<double> verticalExtents() => tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .where((ScrollableState s) => s.position.axis == Axis.vertical)
            .map(
              (ScrollableState s) =>
                  s.position.maxScrollExtent + s.position.viewportDimension,
            )
            .toList();

        final double h = await _measureDefaultHeight(tester, view, day);
        final List<double> uniform = verticalExtents();
        await _pumpCalendar(
          tester,
          view: view,
          day: day,
          heightBuilder: (CalendarResource r, int index, double d) =>
              index == _tallIndex ? d * _tallFactor : null,
        );
        final List<double> variable = verticalExtents();

        // Mọi vùng cuộn dọc (panel resource, timeline) giãn đúng theo tổng
        // chiều cao hàng → hàng cuối cuộn tới được và hai bên vẫn đồng bộ.
        final double ratio =
            (h * (_resourceCount - 1) + h * _tallFactor) / (h * _resourceCount);
        expect(uniform, isNotEmpty);
        expect(variable.length, uniform.length);
        for (int i = 0; i < uniform.length; i++) {
          expect(variable[i], closeTo(uniform[i] * ratio, 0.5), reason: '#$i');
        }
      });
    });
  }
}
