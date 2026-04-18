import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/card.dart' as m;
import '../models/deck.dart';
import '../repositories/card_repository.dart';
import '../repositories/deck_repository.dart';

class DeckScreen extends StatefulWidget {
  final int deckId;
  const DeckScreen({super.key, required this.deckId});

  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  final _deckRepo = DeckRepository();
  final _cardRepo = CardRepository();

  late Future<_DeckPayload> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<_DeckPayload> _load() async {
    final deck = await _deckRepo.byId(widget.deckId);
    if (deck == null) throw StateError('Deck not found');
    final cards = await _cardRepo.byDeck(widget.deckId);
    final due = await _cardRepo.dueInDeck(widget.deckId);
    return _DeckPayload(deck: deck, cards: cards, dueCount: due.length);
  }

  Future<void> _confirmDeleteDeck() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete deck?'),
        content: const Text(
          'All cards and their review history will be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deckRepo.delete(widget.deckId);
      if (mounted) context.pop();
    }
  }

  Future<void> _resetDeckProgress() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset progress?'),
        content: const Text(
          'All cards in this deck return to "new". Review history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _cardRepo.resetDeck(widget.deckId);
      _reload();
    }
  }

  Future<void> _deleteCard(int id) async {
    await _cardRepo.delete(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeckPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        final data = snapshot.data!;
        return _DeckView(
          data: data,
          onAddCard: () async {
            await context.push('/deck/${widget.deckId}/card/new');
            _reload();
          },
          onEditCard: (cardId) async {
            await context.push('/deck/${widget.deckId}/card/$cardId/edit');
            _reload();
          },
          onDeleteCard: _deleteCard,
          onStartReview: data.dueCount == 0
              ? null
              : () async {
                  await context.push('/deck/${widget.deckId}/review');
                  _reload();
                },
          onResetProgress: _resetDeckProgress,
          onDeleteDeck: _confirmDeleteDeck,
        );
      },
    );
  }
}

class _DeckPayload {
  final Deck deck;
  final List<m.Card> cards;
  final int dueCount;
  _DeckPayload({required this.deck, required this.cards, required this.dueCount});
}

class _DeckView extends StatelessWidget {
  final _DeckPayload data;
  final VoidCallback onAddCard;
  final void Function(int cardId) onEditCard;
  final void Function(int cardId) onDeleteCard;
  final VoidCallback? onStartReview;
  final VoidCallback onResetProgress;
  final VoidCallback onDeleteDeck;

  const _DeckView({
    required this.data,
    required this.onAddCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onStartReview,
    required this.onResetProgress,
    required this.onDeleteDeck,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final d = data.deck;
    final newCount = data.cards.where((c) => c.repetitions == 0).length;
    final learning = data.cards.length - newCount;

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'reset':
                  onResetProgress();
                case 'delete':
                  onDeleteDeck();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Reset progress'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete deck'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: t.textTheme.headlineMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      if (d.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          d.description!,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _HeroPill(
                            label: 'Due',
                            value: '${data.dueCount}',
                            highlight: true,
                          ),
                          const SizedBox(width: 10),
                          _HeroPill(label: 'New', value: '$newCount'),
                          const SizedBox(width: 10),
                          _HeroPill(label: 'Learning', value: '$learning'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onStartReview,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.onPrimary,
                            foregroundColor: scheme.primary,
                            disabledBackgroundColor:
                                scheme.onPrimary.withValues(alpha: 0.25),
                            disabledForegroundColor:
                                scheme.onPrimary.withValues(alpha: 0.5),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            data.dueCount == 0
                                ? 'Nothing due'
                                : 'Review ${data.dueCount} card${data.dueCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Cards',
                  style: t.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (data.cards.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyCards(onCreate: onAddCard),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.separated(
                  itemCount: data.cards.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = data.cards[i];
                    return _CardRow(
                      // Key by id so per-row reveal state doesn't leak when
                      // the list reorders or an item is deleted above.
                      key: ValueKey(c.id),
                      card: c,
                      onEdit: () => onEditCard(c.id!),
                      onDelete: () => onDeleteCard(c.id!),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAddCard,
        icon: const Icon(Icons.add),
        label: const Text('Add card'),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _HeroPill({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.onPrimary
              .withValues(alpha: highlight ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: t.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: t.textTheme.titleLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tap a row to reveal its back. Keeping answers hidden by default means you
// can open a deck right before a review session without spoiling yourself.
class _CardRow extends StatefulWidget {
  final m.Card card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardRow({
    super.key,
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<_CardRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final c = widget.card;
    final isNew = c.repetitions == 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _revealed = !_revealed),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isNew ? scheme.primary : scheme.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.front,
                      style: t.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _revealed
                          ? Text(
                              c.back,
                              key: const ValueKey('revealed'),
                              style: t.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Row(
                              key: const ValueKey('hidden'),
                              children: [
                                Icon(
                                  Icons.visibility_off_outlined,
                                  size: 13,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to reveal answer',
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                color: scheme.onSurfaceVariant,
                onPressed: widget.onEdit,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                color: scheme.onSurfaceVariant,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCards extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyCards({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add,
                size: 48, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No cards yet',
              style: t.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Add a card with a front and a back.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
            ),
          ],
        ),
      ),
    );
  }
}
