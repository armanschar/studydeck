class Deck {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const Deck({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  Deck copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Deck.fromMap(Map<String, Object?> m) => Deck(
        id: m['id'] as int?,
        name: m['name'] as String,
        description: m['description'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
