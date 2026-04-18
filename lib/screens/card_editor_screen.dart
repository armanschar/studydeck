import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/card.dart' as m;
import '../repositories/card_repository.dart';

class CardEditorScreen extends StatefulWidget {
  final int deckId;
  final int? cardId;
  const CardEditorScreen({super.key, required this.deckId, this.cardId});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _repo = CardRepository();
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _form = GlobalKey<FormState>();

  m.Card? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.cardId == null) {
      setState(() => _loading = false);
      return;
    }
    final c = await _repo.byId(widget.cardId!);
    if (c != null) {
      _front.text = c.front;
      _back.text = c.back;
      _existing = c;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final front = _front.text.trim();
    final back = _back.text.trim();
    if (_existing != null) {
      await _repo.update(_existing!.copyWith(front: front, back: back));
    } else {
      final now = DateTime.now();
      await _repo.insert(m.Card(
        deckId: widget.deckId,
        front: front,
        back: back,
        createdAt: now,
        dueDate: now,
      ));
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New card' : 'Edit card'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Front',
                      style: t.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _front,
                      autofocus: _existing == null,
                      decoration: const InputDecoration(
                        hintText: 'The question or prompt',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Back',
                      style: t.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _back,
                      decoration: const InputDecoration(
                        hintText: 'The answer',
                      ),
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_existing == null ? 'Create' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
