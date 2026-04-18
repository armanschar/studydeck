// SM-2 spaced-repetition algorithm (Piotr Wozniak, 1990).
// Pure Dart — no Flutter imports, no DB calls. Callers persist the returned
// state and compute the new due-date as `now + intervalDays`.

class SM2Result {
  final double easeFactor;
  final int intervalDays;
  final int repetitions;

  const SM2Result({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
  });
}

const double _minEaseFactor = 1.3;
const double _defaultEaseFactor = 2.5;

/// Apply the user's quality rating and return updated card state.
///
/// `quality` is on the SM-2 0..5 scale:
///   0 = complete blackout, 1 = wrong/familiar, 2 = wrong/easy-on-reveal,
///   3 = correct/hard, 4 = correct/hesitated, 5 = perfect recall.
SM2Result applySM2({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required int quality,
}) {
  assert(quality >= 0 && quality <= 5, 'quality must be 0..5');

  if (quality < 3) {
    return SM2Result(
      easeFactor: easeFactor,
      intervalDays: 1,
      repetitions: 0,
    );
  }

  final int newReps = repetitions + 1;
  final int newInterval;
  if (newReps == 1) {
    newInterval = 1;
  } else if (newReps == 2) {
    newInterval = 6;
  } else {
    newInterval = (intervalDays * easeFactor).round();
  }

  // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
  final double delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
  double newEF = easeFactor + delta;
  if (newEF < _minEaseFactor) newEF = _minEaseFactor;

  return SM2Result(
    easeFactor: newEF,
    intervalDays: newInterval,
    repetitions: newReps,
  );
}

/// Initial state for a freshly created card.
SM2Result initialState() => const SM2Result(
      easeFactor: _defaultEaseFactor,
      intervalDays: 0,
      repetitions: 0,
    );

/// Preview the interval a given quality would produce, without mutating state.
/// Used by the review screen to label the four buttons ("in 1 day", "in 6 days"…).
int previewInterval({
  required double easeFactor,
  required int intervalDays,
  required int repetitions,
  required int quality,
}) {
  return applySM2(
    easeFactor: easeFactor,
    intervalDays: intervalDays,
    repetitions: repetitions,
    quality: quality,
  ).intervalDays;
}
