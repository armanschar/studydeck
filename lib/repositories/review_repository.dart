import '../core/database.dart';
import '../core/sm2.dart';
import '../models/card.dart';
import '../models/review_log.dart';

class ReviewRepository {
  final AppDatabase _db;
  ReviewRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Apply a rating to a card: runs SM-2, updates the card row, and appends
  /// a review_log entry. Wrapped in a transaction so both sides stay consistent.
  Future<Card> applyRating({
    required Card card,
    required int quality,
    DateTime? now,
  }) async {
    assert(card.id != null, 'card must be persisted before reviewing');
    final reviewedAt = now ?? DateTime.now();

    final result = applySM2(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      quality: quality,
    );

    final updated = card.copyWith(
      easeFactor: result.easeFactor,
      intervalDays: result.intervalDays,
      repetitions: result.repetitions,
      dueDate: reviewedAt.add(Duration(days: result.intervalDays)),
    );

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'cards',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await txn.insert('review_log', ReviewLog(
        cardId: updated.id!,
        reviewedAt: reviewedAt,
        quality: quality,
        easeAfter: result.easeFactor,
        intervalAfter: result.intervalDays,
      ).toMap());
    });

    return updated;
  }

  Future<int> reviewsToday() async {
    final db = await _db.database;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM review_log WHERE reviewed_at >= ?',
      [midnight],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<int> reviewsInLastDays(int days) async {
    final db = await _db.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM review_log WHERE reviewed_at >= ?',
      [cutoff],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Retention % over the last [days] days = correct reviews (q >= 3) / total.
  Future<double> retentionLastDays(int days) async {
    final db = await _db.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN quality >= 3 THEN 1 ELSE 0 END) AS correct
      FROM review_log
      WHERE reviewed_at >= ?
    ''', [cutoff]);
    final total = (rows.first['total'] as int?) ?? 0;
    if (total == 0) return 0;
    final correct = (rows.first['correct'] as int?) ?? 0;
    return correct / total;
  }

  /// For the heatmap: counts of reviews per day over the last [days] days.
  /// Returned map keys are date-at-midnight-local; values are review counts.
  Future<Map<DateTime, int>> reviewsPerDay(int days) async {
    final db = await _db.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT reviewed_at FROM review_log WHERE reviewed_at >= ?',
      [cutoff],
    );
    final map = <DateTime, int>{};
    for (final r in rows) {
      final ts = r['reviewed_at'] as int;
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = DateTime(d.year, d.month, d.day);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}
