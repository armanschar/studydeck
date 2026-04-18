class Card {
  final int? id;
  final int deckId;
  final String front;
  final String back;
  final DateTime createdAt;

  // SM-2 state
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueDate;

  const Card({
    this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    required this.dueDate,
  });

  Card copyWith({
    int? id,
    int? deckId,
    String? front,
    String? back,
    DateTime? createdAt,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? dueDate,
  }) {
    return Card(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      createdAt: createdAt ?? this.createdAt,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'deck_id': deckId,
        'front': front,
        'back': back,
        'created_at': createdAt.millisecondsSinceEpoch,
        'ease_factor': easeFactor,
        'interval_days': intervalDays,
        'repetitions': repetitions,
        'due_date': dueDate.millisecondsSinceEpoch,
      };

  factory Card.fromMap(Map<String, Object?> m) => Card(
        id: m['id'] as int?,
        deckId: m['deck_id'] as int,
        front: m['front'] as String,
        back: m['back'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        easeFactor: (m['ease_factor'] as num).toDouble(),
        intervalDays: m['interval_days'] as int,
        repetitions: m['repetitions'] as int,
        dueDate: DateTime.fromMillisecondsSinceEpoch(m['due_date'] as int),
      );
}
