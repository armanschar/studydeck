import '../core/database.dart';
import '../models/card.dart';

class CardRepository {
  final AppDatabase _db;
  CardRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  Future<List<Card>> byDeck(int deckId) async {
    final db = await _db.database;
    final rows = await db.query(
      'cards',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Card.fromMap).toList();
  }

  /// Cards in the deck that are due now (due_date <= now).
  /// Cards with repetitions=0 have due_date set to createdAt, so they're due immediately.
  Future<List<Card>> dueInDeck(int deckId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'cards',
      where: 'deck_id = ? AND due_date <= ?',
      whereArgs: [deckId, now],
      orderBy: 'due_date ASC',
    );
    return rows.map(Card.fromMap).toList();
  }

  Future<Card?> byId(int id) async {
    final db = await _db.database;
    final rows = await db.query('cards', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Card.fromMap(rows.first);
  }

  Future<int> insert(Card card) async {
    final db = await _db.database;
    return db.insert('cards', card.toMap());
  }

  Future<void> update(Card card) async {
    assert(card.id != null, 'update requires card.id');
    final db = await _db.database;
    await db.update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> totalCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM cards');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Cards whose due_date has arrived. Matches [dueInDeck] semantics so the
  /// home screen's "Up to date" and the stats screen's "Due" can never
  /// disagree for the same clock tick.
  Future<int> dueNowCount() async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM cards WHERE due_date <= ?',
      [now],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Reset a deck's cards to fresh SM-2 state. Handy during development.
  Future<void> resetDeck(int deckId) async {
    final db = await _db.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'cards',
      {
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'due_date': now,
      },
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );
  }
}
