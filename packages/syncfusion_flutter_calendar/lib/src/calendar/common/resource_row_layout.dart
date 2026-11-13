import 'package:flutter/foundation.dart';

import '../resource_view/calendar_resource.dart';
import 'event_args.dart';

/// Immutable description of the vertical layout of the resource rows in the
/// timeline views.
///
/// When every row has the same height ([isUniform]) all the calculations use
/// exactly the same formulas as the original single `resourceItemHeight`
/// implementation (`index * height`, `height * count`,
/// `(y / height).truncate()`), so the result is bit-for-bit identical.
/// Otherwise the row offsets are pre-computed once (prefix sums) and queries
/// are O(1) / O(log n).
@immutable
class ResourceRowLayout {
  /// Creates a layout where every row has the given [height].
  const ResourceRowLayout.uniform(double height, this.count)
    : defaultHeight = height,
      _heights = null,
      _offsets = null;

  /// Creates a layout from the optional [builder].
  ///
  /// The builder result of a row is used when it is finite and greater than
  /// zero, otherwise the row uses [defaultHeight]. When [builder] is null, or
  /// it gives no usable height for any row, a uniform layout is returned.
  factory ResourceRowLayout.fromBuilder(
    double defaultHeight,
    List<CalendarResource> resources,
    ResourceItemHeightBuilder? builder,
  ) {
    final int count = resources.length;
    if (builder == null || count == 0) {
      return ResourceRowLayout.uniform(defaultHeight, count);
    }

    final List<double> heights = List<double>.filled(count, defaultHeight);
    bool hasOverride = false;
    for (int i = 0; i < count; i++) {
      final double? value = builder(resources[i], i, defaultHeight);
      if (value == null || !value.isFinite || value <= 0) {
        continue;
      }

      heights[i] = value;
      hasOverride = true;
    }

    if (!hasOverride) {
      return ResourceRowLayout.uniform(defaultHeight, count);
    }

    final List<double> offsets = List<double>.filled(count + 1, 0);
    for (int i = 0; i < count; i++) {
      offsets[i + 1] = offsets[i] + heights[i];
    }

    return ResourceRowLayout._variable(
      defaultHeight,
      count,
      List<double>.unmodifiable(heights),
      List<double>.unmodifiable(offsets),
    );
  }

  const ResourceRowLayout._variable(
    this.defaultHeight,
    this.count,
    List<double> heights,
    List<double> offsets,
  ) : _heights = heights,
      _offsets = offsets;

  /// The height used by rows without an override, and by indexes outside of
  /// `[0, count)`.
  final double defaultHeight;

  /// The number of resource rows.
  final int count;

  // Null for the uniform layout.
  final List<double>? _heights;

  // Length `count + 1`; null for the uniform layout.
  final List<double>? _offsets;

  /// Whether every row has the same height ([defaultHeight]).
  bool get isUniform => _heights == null;

  /// Returns the height of the row at [i]; [defaultHeight] when [i] is outside
  /// of `[0, count)`.
  double heightOf(int i) {
    final List<double>? heights = _heights;
    if (heights == null || i < 0 || i >= count) {
      return defaultHeight;
    }

    return heights[i];
  }

  /// Returns the top offset of the row at [i].
  double topOf(int i) {
    final List<double>? offsets = _offsets;
    if (offsets == null || i <= 0) {
      return i * defaultHeight;
    }

    if (i >= count) {
      return offsets[count] + (i - count) * defaultHeight;
    }

    return offsets[i];
  }

  /// The total height of all the rows.
  double get totalHeight {
    final List<double>? offsets = _offsets;
    return offsets == null ? defaultHeight * count : offsets[count];
  }

  /// Returns the index of the row that contains the vertical position [y].
  ///
  /// The result is not clamped: it is negative for [y] above the first row and
  /// `>= count` for [y] below the last row.
  int indexAt(double y) {
    final List<double>? offsets = _offsets;
    if (offsets == null || y < 0) {
      return (y / defaultHeight).truncate();
    }

    final double total = offsets[count];
    if (y >= total) {
      return count + ((y - total) / defaultHeight).truncate();
    }

    // Largest index `i` where `offsets[i] <= y`.
    int low = 0;
    int high = count - 1;
    while (low < high) {
      final int mid = (low + high + 1) >> 1;
      if (offsets[mid] <= y) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return low;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! ResourceRowLayout ||
        other.defaultHeight != defaultHeight ||
        other.count != count ||
        other.isUniform != isUniform) {
      return false;
    }

    final List<double>? heights = _heights;
    final List<double>? otherHeights = other._heights;
    if (heights == null || otherHeights == null) {
      return true;
    }

    for (int i = 0; i < heights.length; i++) {
      if (heights[i] != otherHeights[i]) {
        return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(
    defaultHeight,
    count,
    isUniform,
    _heights == null ? 0 : Object.hashAll(_heights),
  );
}
