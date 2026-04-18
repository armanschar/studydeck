class ReviewLog {
  final int? id;
  final int cardId;
  final DateTime reviewedAt;
  final int quality;
  final double easeAfter;
  final int intervalAfter;

  const ReviewLog({
    this.id,
    required this.cardId,
    required this.reviewedAt,
    required this.quality,
    required this.easeAfter,
    required this.intervalAfter,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'card_id': cardId,
        'reviewed_at': reviewedAt.millisecondsSinceEpoch,
        'quality': quality,
        'ease_after': easeAfter,
        'interval_after': intervalAfter,
      };

  factory ReviewLog.fromMap(Map<String, Object?> m) => ReviewLog(
        id: m['id'] as int?,
        cardId: m['card_id'] as int,
        reviewedAt:
            DateTime.fromMillisecondsSinceEpoch(m['reviewed_at'] as int),
        quality: m['quality'] as int,
        easeAfter: (m['ease_after'] as num).toDouble(),
        intervalAfter: m['interval_after'] as int,
      );
}
