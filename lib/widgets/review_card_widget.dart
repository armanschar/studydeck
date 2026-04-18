import 'dart:math' as math;
import 'package:flutter/material.dart';

// 3D flip card. Rotates around the Y axis from front to back and back.
// The parent controls `showBack` via setState — this widget animates the rest.

class FlipCard extends StatefulWidget {
  final bool showBack;
  final Widget front;
  final Widget back;
  final Duration duration;

  const FlipCard({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (widget.showBack) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant FlipCard old) {
    super.didUpdateWidget(old);
    if (old.showBack != widget.showBack) {
      if (widget.showBack) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final v = _ctrl.value;
        final angle = v * math.pi;
        final showingBack = v >= 0.5;
        final child = showingBack
            ? Transform(
                transform: Matrix4.identity()..rotateY(math.pi),
                alignment: Alignment.center,
                child: widget.back,
              )
            : widget.front;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012) // perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: child,
        );
      },
    );
  }
}

// Styled card surface for front/back faces. Used inside FlipCard.
class ReviewCardFace extends StatelessWidget {
  final String primary;
  final String? secondary;
  final String? hint;
  final bool isBack;

  const ReviewCardFace({
    super.key,
    required this.primary,
    this.secondary,
    this.hint,
    this.isBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isBack ? scheme.primaryContainer : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isBack ? 'ANSWER' : 'QUESTION',
            style: t.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: isBack
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                primary,
                style: t.textTheme.displaySmall?.copyWith(
                  color: isBack
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: (isBack ? scheme.onPrimaryContainer : scheme.outlineVariant)
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  secondary!,
                  style: t.textTheme.headlineSmall?.copyWith(
                    color: isBack
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.85)
                        : scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
          if (hint != null) ...[
            const SizedBox(height: 28),
            Text(
              hint!,
              style: t.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
