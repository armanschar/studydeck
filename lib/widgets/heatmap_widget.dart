import 'package:flutter/material.dart';

// GitHub-style contribution heatmap: 7 rows (Sun..Sat) × N weeks.
// Keys in `data` must be midnight-local dates; values are review counts.

class HeatmapWidget extends StatelessWidget {
  final Map<DateTime, int> data;
  final int weeks;
  final double cellSize;
  final double cellGap;

  const HeatmapWidget({
    super.key,
    required this.data,
    this.weeks = 20,
    this.cellSize = 14,
    this.cellGap = 3,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.primary;
    final empty = Theme.of(context).colorScheme.surfaceContainerHighest;

    final width = weeks * (cellSize + cellGap) - cellGap;
    final height = 7 * (cellSize + cellGap) - cellGap;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _HeatmapPainter(
          data: data,
          weeks: weeks,
          cellSize: cellSize,
          cellGap: cellGap,
          base: base,
          empty: empty,
          max: data.values.fold<int>(0, (m, v) => v > m ? v : m),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Map<DateTime, int> data;
  final int weeks;
  final double cellSize;
  final double cellGap;
  final Color base;
  final Color empty;
  final int max;

  _HeatmapPainter({
    required this.data,
    required this.weeks,
    required this.cellSize,
    required this.cellGap,
    required this.base,
    required this.empty,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Anchor today at the last column in its weekday row. Start = the Sunday
    // that begins the week `weeks-1` weeks before today's week.
    final todayRow = today.weekday % 7; // 0=Sun..6=Sat
    final start = DateTime(
      today.year,
      today.month,
      today.day - todayRow - (weeks - 1) * 7,
    );

    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final day = DateTime(start.year, start.month, start.day + w * 7 + d);
        final dx = w * (cellSize + cellGap);
        final dy = d * (cellSize + cellGap);
        final rect = Rect.fromLTWH(dx, dy, cellSize, cellSize);

        if (day.isAfter(today)) {
          paint.color = empty.withValues(alpha: 0.4);
        } else {
          final count = data[day] ?? 0;
          paint.color = count == 0
              ? empty
              : base.withValues(alpha: _intensity(count));
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
    }
  }

  double _intensity(int count) {
    final ratio = count / max;
    // Four-stop gradient like GitHub: 0.25, 0.5, 0.75, 1.0
    if (ratio <= 0.25) return 0.35;
    if (ratio <= 0.5) return 0.55;
    if (ratio <= 0.75) return 0.8;
    return 1.0;
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) {
    return old.data != data ||
        old.weeks != weeks ||
        old.base != base ||
        old.empty != empty ||
        old.max != max;
  }
}
