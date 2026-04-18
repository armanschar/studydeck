import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/deck.dart';
import '../repositories/deck_repository.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _decksKey = GlobalKey<_DecksTabState>();
  final _statsKey = GlobalKey<StatsScreenState>();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _DecksTab(key: _decksKey),
          StatsScreen(key: _statsKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          // IndexedStack keeps both tabs alive, so initState doesn't re-fire.
          // Refresh whichever tab the user just switched to.
          if (i == 0) _decksKey.currentState?.reload();
          if (i == 1) _statsKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Decks',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _decksKey.currentState?.createDeck(),
              icon: const Icon(Icons.add),
              label: const Text('New deck'),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            )
          : null,
    );
  }
}

class _DecksTab extends StatefulWidget {
  const _DecksTab({super.key});
  @override
  State<_DecksTab> createState() => _DecksTabState();
}

class _DecksTabState extends State<_DecksTab> {
  final _repo = DeckRepository();
  late Future<List<DeckWithCounts>> _future;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    // Block body so setState's callback returns void. Arrow-form here would
    // return the Future from the assignment, which Flutter flags in debug.
    setState(() {
      _future = _repo.allWithCounts();
    });
  }

  Future<void> createDeck() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _DeckEditorDialog(repo: _repo),
    );
    if (created == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: FutureBuilder<List<DeckWithCounts>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final decks = snapshot.data ?? const [];
          final totalDue =
              decks.fold<int>(0, (sum, d) => sum + d.dueCards);
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Hero(totalDue: totalDue, deckCount: decks.length),
                ),
                if (decks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyDecks(onCreate: createDeck),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Your decks',
                        style: t.textTheme.titleMedium?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: decks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _DeckCard(
                        item: decks[i],
                        onOpen: () async {
                          await context.push('/deck/${decks[i].deck.id}');
                          reload();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int totalDue;
  final int deckCount;
  const _Hero({required this.totalDue, required this.deckCount});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final greeting = _greeting();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Container(
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: t.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              totalDue == 0 ? 'All caught up' : '$totalDue to review',
              style: t.textTheme.headlineLarge?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deckCount == 0
                  ? 'Create your first deck to get started.'
                  : totalDue == 0
                      ? 'No cards due across $deckCount deck${deckCount == 1 ? '' : 's'}.'
                      : 'Across $deckCount deck${deckCount == 1 ? '' : 's'}.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late night studying?';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DeckCard extends StatelessWidget {
  final DeckWithCounts item;
  final VoidCallback onOpen;
  const _DeckCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final d = item.deck;
    final progress = item.totalCards == 0
        ? 0.0
        : (item.totalCards - item.dueCards) / item.totalCards;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.dueCards > 0
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.layers_rounded,
                      color: item.dueCards > 0
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.name,
                          style: t.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (d.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            d.description!,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.dueCards > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${item.dueCards}',
                        style: t.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(scheme.primary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaDot(
                    label: '${item.totalCards} card${item.totalCards == 1 ? '' : 's'}',
                    icon: Icons.style_outlined,
                  ),
                  const SizedBox(width: 16),
                  if (item.dueCards > 0)
                    _MetaDot(
                      label: '${item.dueCards} due',
                      icon: Icons.schedule,
                      color: scheme.primary,
                    )
                  else
                    _MetaDot(
                      label: 'Up to date',
                      icon: Icons.check_circle_outline,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaDot extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _MetaDot({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = color ?? t.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(
          label,
          style: t.textTheme.labelMedium?.copyWith(color: c),
        ),
      ],
    );
  }
}

class _EmptyDecks extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyDecks({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: t.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_stories,
                size: 40,
                color: t.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('No decks yet', style: t.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Create your first deck and start studying.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create a deck'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckEditorDialog extends StatefulWidget {
  final DeckRepository repo;
  const _DeckEditorDialog({required this.repo});

  @override
  State<_DeckEditorDialog> createState() => _DeckEditorDialogState();
}

class _DeckEditorDialogState extends State<_DeckEditorDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.repo.insert(Deck(
      name: _name.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('New deck'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
