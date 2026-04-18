import 'package:flutter/material.dart';

import '../repositories/card_repository.dart';
import '../repositories/review_repository.dart';
import '../widgets/heatmap_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final _cardRepo = CardRepository();
  final _reviewRepo = ReviewRepository();
  late Future<_StatsPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<_StatsPayload> _load() async {
    final results = await Future.wait([
      _reviewRepo.reviewsToday(),
      _cardRepo.totalCount(),
      _cardRepo.dueNowCount(),
      _reviewRepo.retentionLastDays(30),
      _reviewRepo.reviewsPerDay(140),
      _reviewRepo.reviewsInLastDays(30),
    ]);
    return _StatsPayload(
      reviewsToday: results[0] as int,
      totalCards: results[1] as int,
      dueNow: results[2] as int,
      retention: results[3] as double,
      heatmap: results[4] as Map<DateTime, int>,
      reviews30d: results[5] as int,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: reload,
          ),
        ],
      ),
      body: FutureBuilder<_StatsPayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          final hasHistory = data.reviews30d > 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _HeroBanner(
                reviewsToday: data.reviewsToday,
                dueNow: data.dueNow,
              ),
              const SizedBox(height: 24),
              Text(
                'Overview',
                style: t.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _MetricCard(
                    label: 'Reviewed today',
                    value: '${data.reviewsToday}',
                    icon: Icons.today,
                    tint: scheme.primary,
                  ),
                  _MetricCard(
                    label: 'Due now',
                    value: '${data.dueNow}',
                    icon: Icons.event,
                    tint: scheme.tertiary,
                  ),
                  _MetricCard(
                    label: 'Total cards',
                    value: '${data.totalCards}',
                    icon: Icons.style,
                    tint: scheme.secondary,
                  ),
                  _MetricCard(
                    label: 'Retention (30d)',
                    value: hasHistory
                        ? '${(data.retention * 100).round()}%'
                        : '—',
                    icon: Icons.trending_up,
                    tint: scheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Activity',
                style: t.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: data.heatmap.isEmpty
                      ? Column(
                          children: [
                            Icon(Icons.insights,
                                size: 40, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text(
                              'Review some cards to fill this in.',
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last 20 weeks',
                              style: t.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              reverse: true,
                              child: HeatmapWidget(data: data.heatmap),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Less',
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                for (final a in [0.35, 0.55, 0.8, 1.0])
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color:
                                            scheme.primary.withValues(alpha: a),
                                        borderRadius:
                                            BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  'More',
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int reviewsToday;
  final int dueNow;
  const _HeroBanner({required this.reviewsToday, required this.dueNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final title = reviewsToday == 0 && dueNow == 0
        ? 'Nothing pending'
        : reviewsToday > 0 && dueNow == 0
            ? 'You cleared your queue'
            : reviewsToday == 0
                ? '$dueNow due now'
                : 'Reviewed $reviewsToday, $dueNow to go';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.22),
              scheme.primary,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: t.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: t.textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPayload {
  final int reviewsToday;
  final int totalCards;
  final int dueNow;
  final double retention;
  final Map<DateTime, int> heatmap;
  final int reviews30d;

  _StatsPayload({
    required this.reviewsToday,
    required this.totalCards,
    required this.dueNow,
    required this.retention,
    required this.heatmap,
    required this.reviews30d,
  });
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tint, size: 20),
            ),
            Text(
              value,
              style: t.textTheme.headlineLarge,
            ),
            Text(
              label,
              style: t.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
