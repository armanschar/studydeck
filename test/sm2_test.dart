import 'package:flutter_test/flutter_test.dart';
import 'package:studydeck/core/sm2.dart';

void main() {
  group('applySM2 — failure branch (quality < 3)', () {
    test('quality=0 resets repetitions to 0 and interval to 1', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 30,
        repetitions: 5,
        quality: 0,
      );
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
    });

    test('quality=2 still counts as a failure', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 15,
        repetitions: 3,
        quality: 2,
      );
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
    });

    test('ease factor is unchanged on failure', () {
      final r = applySM2(
        easeFactor: 2.1,
        intervalDays: 10,
        repetitions: 4,
        quality: 1,
      );
      expect(r.easeFactor, 2.1);
    });
  });

  group('applySM2 — interval progression on success', () {
    test('first successful review → 1 day', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        quality: 4,
      );
      expect(r.repetitions, 1);
      expect(r.intervalDays, 1);
    });

    test('second successful review → 6 days', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 1,
        quality: 4,
      );
      expect(r.repetitions, 2);
      expect(r.intervalDays, 6);
    });

    test('third successful review → interval × EF, rounded', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 5,
      );
      expect(r.repetitions, 3);
      expect(r.intervalDays, 15); // 6 * 2.5 = 15
    });
  });

  group('applySM2 — ease factor updates', () {
    test('quality=5 increases EF by 0.1', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 5,
      );
      expect(r.easeFactor, closeTo(2.6, 1e-9));
    });

    test('quality=4 leaves EF unchanged', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 4,
      );
      expect(r.easeFactor, closeTo(2.5, 1e-9));
    });

    test('quality=3 decreases EF', () {
      final r = applySM2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 3,
      );
      // EF' = 2.5 + (0.1 - 2*(0.08 + 2*0.02)) = 2.5 + 0.1 - 0.24 = 2.36
      expect(r.easeFactor, closeTo(2.36, 1e-9));
    });

    test('EF is floored at 1.3', () {
      // Start at the floor, answer with minimum passing quality repeatedly.
      var ef = 1.3;
      for (var i = 0; i < 10; i++) {
        final r = applySM2(
          easeFactor: ef,
          intervalDays: 1,
          repetitions: 1,
          quality: 3,
        );
        ef = r.easeFactor;
      }
      expect(ef, 1.3);
    });
  });

  group('initialState', () {
    test('fresh card starts with EF=2.5, interval=0, reps=0', () {
      final s = initialState();
      expect(s.easeFactor, 2.5);
      expect(s.intervalDays, 0);
      expect(s.repetitions, 0);
    });
  });

  group('previewInterval', () {
    test('matches applySM2 intervalDays for same inputs', () {
      final preview = previewInterval(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 5,
      );
      final applied = applySM2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 5,
      );
      expect(preview, applied.intervalDays);
    });
  });

  group('asserts', () {
    test('quality outside 0..5 trips the assert in debug mode', () {
      expect(
        () => applySM2(
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          quality: 6,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
