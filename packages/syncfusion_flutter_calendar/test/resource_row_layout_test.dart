import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:syncfusion_flutter_calendar/src/calendar/common/resource_row_layout.dart';

List<CalendarResource> _resources(int count) => List<CalendarResource>.generate(
  count,
  (int i) => CalendarResource(id: 'r$i', displayName: 'Resource $i'),
);

void main() {
  group('uniform layout (bit-for-bit with the single height)', () {
    const int count = 7;
    for (final double h in <double>[46, 46.3, 33.333]) {
      test('h = $h', () {
        const List<double> factors = <double>[
          -2.5,
          -1,
          -0.0001,
          0,
          0.0001,
          0.4,
          0.999,
          1,
          1.0001,
          3,
          3.5,
          6.9999,
          7,
          7.0001,
          9.2,
          15,
        ];
        final ResourceRowLayout layout = ResourceRowLayout.uniform(h, count);
        expect(layout.isUniform, isTrue);
        expect(layout.count, count);
        expect(layout.defaultHeight, h);

        for (int i = -3; i <= count + 3; i++) {
          expect(layout.topOf(i), i * h, reason: 'topOf($i)');
          expect(layout.heightOf(i), h, reason: 'heightOf($i)');
        }
        expect(layout.totalHeight, h * count);

        final List<double> ys = <double>[
          for (final double f in factors) f * h,
          for (int i = -2; i <= count + 2; i++) i * h,
          for (int i = -2; i <= count + 2; i++) i * h - 0.0001,
          for (int i = -2; i <= count + 2; i++) i * h + 0.0001,
          h * count,
          h * count + 1,
          -1,
          -h,
        ];
        for (final double y in ys) {
          expect(layout.indexAt(y), (y / h).truncate(), reason: 'indexAt($y)');
        }
      });

      test('accumulating loop yields the same sequence, h = $h', () {
        final ResourceRowLayout layout = ResourceRowLayout.uniform(h, count);
        double expected = 0;
        double actual = 0;
        for (int i = 0; i < count; i++) {
          expect(actual, expected, reason: 'row $i');
          expected += h;
          actual += layout.heightOf(i);
        }
        expect(actual, expected);
      });
    }
  });

  group('variable layout', () {
    const double h = 46;
    const int count = 6;

    ResourceRowLayout build() => ResourceRowLayout.fromBuilder(
      h,
      _resources(count),
      (CalendarResource r, int i, double d) => i == 1 ? d * 1.5 : null,
    );

    test('is not uniform and exposes heights', () {
      final ResourceRowLayout layout = build();
      expect(layout.isUniform, isFalse);
      expect(layout.count, count);
      expect(layout.defaultHeight, h);
      for (int i = 0; i < count; i++) {
        expect(layout.heightOf(i), i == 1 ? h * 1.5 : h, reason: 'row $i');
      }
    });

    test('builder receives resource, index and default height', () {
      final List<CalendarResource> resources = _resources(3);
      final List<String> seen = <String>[];
      ResourceRowLayout.fromBuilder(h, resources, (
        CalendarResource r,
        int i,
        double d,
      ) {
        expect(identical(r, resources[i]), isTrue);
        expect(d, h);
        seen.add('$i');
        return null;
      });
      expect(seen, <String>['0', '1', '2']);
    });

    test('topOf is the prefix sum and topOf(count) == totalHeight', () {
      final ResourceRowLayout layout = build();
      double sum = 0;
      for (int i = 0; i < count; i++) {
        expect(layout.topOf(i), sum, reason: 'topOf($i)');
        sum += layout.heightOf(i);
      }
      expect(layout.topOf(count), sum);
      expect(layout.totalHeight, sum);
      expect(layout.totalHeight, h * (count - 1) + h * 1.5);
    });

    test('indexAt resolves every y inside a row to that row', () {
      final ResourceRowLayout layout = build();
      for (int i = 0; i < count; i++) {
        final double top = layout.topOf(i);
        final double bottom = layout.topOf(i + 1);
        expect(layout.indexAt(top), i, reason: 'top of row $i');
        expect(layout.indexAt((top + bottom) / 2), i, reason: 'mid of row $i');
        expect(
          layout.indexAt(bottom - 0.0001),
          i,
          reason: 'just above bottom of row $i',
        );
        for (double y = top; y < bottom; y += 0.5) {
          expect(layout.indexAt(y), i, reason: 'y=$y');
        }
      }
    });

    test('out of range follows the default height', () {
      final ResourceRowLayout layout = build();
      final double total = layout.totalHeight;
      expect(layout.heightOf(-1), h);
      expect(layout.heightOf(count), h);
      expect(layout.topOf(0), 0);
      expect(layout.topOf(-2), -2 * h);
      expect(layout.topOf(count + 2), total + 2 * h);

      expect(layout.indexAt(-1), (-1 / h).truncate());
      expect(layout.indexAt(-2.5 * h), (-2.5).truncate());
      expect(layout.indexAt(total), count);
      expect(layout.indexAt(total + 0.5 * h), count);
      expect(layout.indexAt(total + h), count + 1);
      expect(layout.indexAt(total + 2.5 * h), count + 2);
    });

    test('single row layout', () {
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        _resources(1),
        (CalendarResource r, int i, double d) => 100,
      );
      expect(layout.isUniform, isFalse);
      expect(layout.totalHeight, 100);
      expect(layout.indexAt(0), 0);
      expect(layout.indexAt(99.9), 0);
      expect(layout.indexAt(100), 1);
    });
  });

  group('builder results', () {
    const double h = 40;

    test('null builder is uniform', () {
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        _resources(4),
        null,
      );
      expect(layout.isUniform, isTrue);
      expect(layout, const ResourceRowLayout.uniform(h, 4));
    });

    test('all null results are uniform', () {
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        _resources(4),
        (CalendarResource r, int i, double d) => null,
      );
      expect(layout.isUniform, isTrue);
      expect(layout, const ResourceRowLayout.uniform(h, 4));
    });

    test('invalid results fall back to the default height', () {
      final List<double?> results = <double?>[
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0,
        -5,
        60,
      ];
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        _resources(results.length),
        (CalendarResource r, int i, double d) => results[i],
      );
      expect(layout.isUniform, isFalse);
      for (int i = 0; i < results.length - 1; i++) {
        expect(layout.heightOf(i), h, reason: 'row $i');
      }
      expect(layout.heightOf(results.length - 1), 60);
      expect(layout.totalHeight, h * (results.length - 1) + 60);
    });

    test('all invalid results are uniform', () {
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        _resources(3),
        (CalendarResource r, int i, double d) =>
            <double>[double.nan, double.infinity, -1][i],
      );
      expect(layout.isUniform, isTrue);
      expect(layout.totalHeight, h * 3);
    });

    test('empty resources is uniform with zero total', () {
      final ResourceRowLayout layout = ResourceRowLayout.fromBuilder(
        h,
        const <CalendarResource>[],
        (CalendarResource r, int i, double d) => 10,
      );
      expect(layout.isUniform, isTrue);
      expect(layout.count, 0);
      expect(layout.totalHeight, 0);
    });
  });

  group('equality', () {
    ResourceRowLayout make(double h, double? row1) =>
        ResourceRowLayout.fromBuilder(
          h,
          _resources(4),
          (CalendarResource r, int i, double d) => i == 1 ? row1 : null,
        );

    test('uniform layouts', () {
      expect(
        const ResourceRowLayout.uniform(46, 5),
        const ResourceRowLayout.uniform(46, 5),
      );
      expect(
        const ResourceRowLayout.uniform(46, 5).hashCode,
        const ResourceRowLayout.uniform(46, 5).hashCode,
      );
      expect(
        const ResourceRowLayout.uniform(46, 5),
        isNot(const ResourceRowLayout.uniform(47, 5)),
      );
      expect(
        const ResourceRowLayout.uniform(46, 5),
        isNot(const ResourceRowLayout.uniform(46, 6)),
      );
    });

    test('variable layouts', () {
      expect(make(46, 69), make(46, 69));
      expect(make(46, 69).hashCode, make(46, 69).hashCode);
      expect(make(46, 69), isNot(make(46, 70)));
      expect(make(46, 69), isNot(make(40, 69)));
    });

    test('uniform differs from variable', () {
      expect(make(46, 69), isNot(const ResourceRowLayout.uniform(46, 4)));
      expect(const ResourceRowLayout.uniform(46, 4), isNot(make(46, 69)));
      expect(make(46, null), const ResourceRowLayout.uniform(46, 4));
    });
  });
}
