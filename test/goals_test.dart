import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/models/goal_record.dart';

void main() {
  group('GoalRecord', () {
    test('calculates progress ratio correctly', () {
      final GoalRecord goal = GoalRecord(
        id: '1',
        title: 'Acil Fonu',
        targetAmount: 10000,
        savedAmount: 4000,
        category: 'Tasarruf',
      );

      expect(goal.progressRatio, 0.4);
      expect(goal.remainingAmount, 6000);
      expect(goal.isCompleted, isFalse);
    });

    test('handles completion and overflow progress', () {
      final GoalRecord goal = GoalRecord(
        id: '2',
        title: 'Tatil',
        targetAmount: 5000,
        savedAmount: 6000,
        category: 'Seyahat',
      );

      expect(goal.progressRatio, 1.0);
      expect(goal.remainingAmount, 0);
      expect(goal.isCompleted, isTrue);
    });

    test('calculates days remaining for future target date', () {
      final DateTime futureDate = DateTime.now().add(const Duration(days: 45));
      final GoalRecord goal = GoalRecord(
        id: '3',
        title: 'MacBook',
        targetAmount: 50000,
        savedAmount: 10000,
        category: 'Teknoloji',
        targetDate: futureDate,
      );

      expect(goal.daysRemaining, isNotNull);
      expect(goal.daysRemaining! >= 44 && goal.daysRemaining! <= 46, isTrue);
    });

    test('toMap and fromMap serialize accurately', () {
      final DateTime date = DateTime(2026, 12, 31);
      final GoalRecord original = GoalRecord(
        id: 'test-123',
        title: 'Ev Peşinatı',
        targetAmount: 500000,
        savedAmount: 150000,
        category: 'Ev',
        targetDate: date,
        note: 'Yıl sonu hedefi',
      );

      final Map<String, Object?> map = original.toMap();
      final GoalRecord restored = GoalRecord.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.targetAmount, original.targetAmount);
      expect(restored.savedAmount, original.savedAmount);
      expect(restored.category, original.category);
      expect(restored.targetDate?.year, 2026);
      expect(restored.note, original.note);
    });
  });
}
