import '../core/database.dart';
import '../models/deck.dart';

class DeckWithCounts {
  final Deck deck;
  final int totalCards;
  final int dueCards;

  const DeckWithCounts({
    required this.deck,
    required this.totalCards,
    required this.dueCards,
  });
}

class DeckRepository {
  final AppDatabase _db;
  DeckRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<List<Deck>> all() async {
    final db = await _db.database;
    final rows = await db.query('decks', orderBy: 'created_at DESC');
    return rows.map(Deck.fromMap).toList();
  }

  Future<List<DeckWithCounts>> allWithCounts() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT d.*,
        (SELECT COUNT(*) FROM cards c WHERE c.deck_id = d.id) AS total_cards,
        (SELECT COUNT(*) FROM cards c WHERE c.deck_id = d.id AND c.due_date <= ?) AS due_cards
      FROM decks d
      ORDER BY d.created_at DESC
    ''', [now]);
    return rows
        .map((r) => DeckWithCounts(
              deck: Deck.fromMap(r),
              totalCards: (r['total_cards'] as int?) ?? 0,
              dueCards: (r['due_cards'] as int?) ?? 0,
            ))
        .toList();
  }

  Future<Deck?> byId(int id) async {
    final db = await _db.database;
    final rows = await db.query('decks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  Future<int> insert(Deck deck) async {
    final db = await _db.database;
    return db.insert('decks', deck.toMap());
  }

  Future<void> update(Deck deck) async {
    assert(deck.id != null, 'update requires deck.id');
    final db = await _db.database;
    await db.update('decks', deck.toMap(), where: 'id = ?', whereArgs: [deck.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('decks', where: 'id = ?', whereArgs: [id]);
  }
}
