import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'studydeck.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE decks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        description TEXT,
        created_at  INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE cards (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id       INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
        front         TEXT NOT NULL,
        back          TEXT NOT NULL,
        created_at    INTEGER NOT NULL,
        ease_factor   REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions   INTEGER NOT NULL DEFAULT 0,
        due_date      INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE review_log (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        card_id        INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
        reviewed_at    INTEGER NOT NULL,
        quality        INTEGER NOT NULL,
        ease_after     REAL NOT NULL,
        interval_after INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_cards_deck_id ON cards(deck_id)');
    await db.execute('CREATE INDEX idx_cards_due_date ON cards(due_date)');
    await db.execute('CREATE INDEX idx_review_log_card_id ON review_log(card_id)');

    await _seedDemoData(db);
  }

  // Seed one demo deck with 5 cards so the app isn't empty on first launch.
  Future<void> _seedDemoData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deckId = await db.insert('decks', {
      'name': 'Capitals of the World',
      'description': 'A starter deck — edit or delete freely.',
      'created_at': now,
    });

    const cards = [
      ('France', 'Paris'),
      ('Japan', 'Tokyo'),
      ('Brazil', 'Brasília'),
      ('Australia', 'Canberra'),
      ('Canada', 'Ottawa'),
    ];
    for (final (front, back) in cards) {
      await db.insert('cards', {
        'deck_id': deckId,
        'front': front,
        'back': back,
        'created_at': now,
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'due_date': now,
      });
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
