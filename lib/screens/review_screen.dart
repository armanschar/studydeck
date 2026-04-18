import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/sm2.dart';
import '../core/theme.dart';
import '../models/card.dart' as m;
import '../repositories/card_repository.dart';
import '../repositories/review_repository.dart';
import '../widgets/review_card_widget.dart';

class ReviewScreen extends StatefulWidget {
  final int deckId;
  const ReviewScreen({super.key, required this.deckId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _cardRepo = CardRepository();
  final _reviewRepo = ReviewRepository();

  List<m.Card> _queue = const [];
  int _index = 0;
  bool _revealed = false;
  bool _loading = true;
  bool _submitting = false;

  int _reviewed = 0;
  int _correct = 0;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    final due = await _cardRepo.dueInDeck(widget.deckId);
    if (!mounted) return;
    setState(() {
      _queue = due;
      _loading = false;
    });
  }

  Future<void> _rate(int quality) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Light tick on tap so the button press feels physical.
    HapticFeedback.selectionClick();
    final current = _queue[_index];
    await _reviewRepo.applyRating(card: current, quality: quality);
    if (!mounted) return;
    // Collapse back to the front face briefly so the next card doesn't
    // appear pre-revealed as the flip eases back.
    setState(() => _revealed = false);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final finished = _index + 1 >= _queue.length;
    setState(() {
      _reviewed += 1;
      if (quality >= 3) _correct += 1;
      _index += 1;
      _submitting = false;
    });
    if (finished) {
      // Heavier "you did it" pulse when the queue empties.
      HapticFeedback.mediumImpact();
    }
  }

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing due right now.')),
      );
    }
    if (_index >= _queue.length) {
      return _SummaryView(
        reviewed: _reviewed,
        correct: _correct,
        elapsed: DateTime.now().difference(_startedAt),
        onDone: () => context.pop(),
      );
    }

    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final card = _queue[_index];
    final progress = _index / _queue.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${_index + 1} of ${_queue.length}',
          style: t.textTheme.titleMedium,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                backgroundColor: scheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _revealed ? null : _reveal,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: FlipCard(
                      showBack: _revealed,
                      front: ReviewCardFace(
                        primary: card.front,
                        hint: 'Tap to reveal answer',
                      ),
                      back: ReviewCardFace(
                        primary: card.front,
                        secondary: card.back,
                        isBack: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: _revealed
                  ? _RatingBar(
                      key: const ValueKey('rating'),
                      card: card,
                      onRate: _rate,
                      disabled: _submitting,
                    )
                  : Padding(
                      key: const ValueKey('show'),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _reveal,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Show answer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final m.Card card;
  final void Function(int quality) onRate;
  final bool disabled;
  const _RatingBar({
    super.key,
    required this.card,
    required this.onRate,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Again=1, Hard=3, Good=4, Easy=5. Hard/Good use scheme colors; Again/Easy
    // use the semantic constants so red/green read as "fail/easy" in both modes.
    final buttons = <_RatingSpec>[
      _RatingSpec(
        label: 'Again',
        quality: 1,
        bg: AppTheme.ratingAgain,
        fg: Colors.white,
      ),
      _RatingSpec(
        label: 'Hard',
        quality: 3,
        bg: scheme.surfaceContainerHighest,
        fg: scheme.onSurface,
      ),
      _RatingSpec(
        label: 'Good',
        quality: 4,
        bg: scheme.primary,
        fg: scheme.onPrimary,
      ),
      _RatingSpec(
        label: 'Easy',
        quality: 5,
        bg: AppTheme.ratingEasy,
        fg: Colors.white,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: Row(
        children: [
          for (final b in buttons)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _RatingButton(
                  spec: b,
                  card: card,
                  onRate: onRate,
                  disabled: disabled,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingSpec {
  final String label;
  final int quality;
  final Color bg;
  final Color fg;
  const _RatingSpec({
    required this.label,
    required this.quality,
    required this.bg,
    required this.fg,
  });
}

class _RatingButton extends StatelessWidget {
  final _RatingSpec spec;
  final m.Card card;
  final void Function(int quality) onRate;
  final bool disabled;

  const _RatingButton({
    required this.spec,
    required this.card,
    required this.onRate,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final days = previewInterval(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      quality: spec.quality,
    );
    final interval = _formatInterval(days);
    return FilledButton(
      onPressed: disabled ? null : () => onRate(spec.quality),
      style: FilledButton.styleFrom(
        backgroundColor: spec.bg,
        foregroundColor: spec.fg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spec.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            interval,
            style: TextStyle(
              fontSize: 11,
              color: spec.fg.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInterval(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return '1d';
  if (days < 30) return '${days}d';
  if (days < 365) {
    final months = (days / 30).round();
    return months == 1 ? '1mo' : '${months}mo';
  }
  final years = (days / 365).round();
  return years == 1 ? '1y' : '${years}y';
}

class _SummaryView extends StatelessWidget {
  final int reviewed;
  final int correct;
  final Duration elapsed;
  final VoidCallback onDone;

  const _SummaryView({
    required this.reviewed,
    required this.correct,
    required this.elapsed,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final accuracy = reviewed == 0 ? 0 : (correct * 100 / reviewed).round();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onDone,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Session complete',
                style: t.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Great work — here\'s how it went.',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _SummaryRow(
                icon: Icons.style,
                label: 'Reviewed',
                value: '$reviewed card${reviewed == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.trending_up,
                label: 'Accuracy',
                value: '$accuracy%',
              ),
              const SizedBox(height: 12),
              _SummaryRow(
                icon: Icons.schedule,
                label: 'Time spent',
                value: _formatElapsed(elapsed),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: t.textTheme.titleSmall)),
          Text(value, style: t.textTheme.titleMedium),
        ],
      ),
    );
  }
}

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  if (minutes == 0) return '${seconds}s';
  return '${minutes}m ${seconds}s';
}
