class GoalRecord {
  const GoalRecord({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    required this.category,
    this.targetDate,
    this.note,
    this.colorHex,
  });

  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final String category;
  final DateTime? targetDate;
  final String? note;
  final String? colorHex;

  double get progressRatio =>
      targetAmount <= 0 ? 1.0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  double get remainingAmount =>
      (targetAmount - savedAmount) > 0 ? targetAmount - savedAmount : 0.0;

  bool get isCompleted => savedAmount >= targetAmount && targetAmount > 0;

  int? get daysRemaining {
    if (targetDate == null) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }

  GoalRecord copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    String? category,
    DateTime? targetDate,
    String? note,
    String? colorHex,
  }) {
    return GoalRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      category: category ?? this.category,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'category': category,
        'target_date': targetDate?.toIso8601String(),
        'note': note,
        'color_hex': colorHex,
      };

  factory GoalRecord.fromMap(Map<String, Object?> map) {
    return GoalRecord(
      id: map['id']! as String,
      title: map['title']! as String,
      targetAmount: (map['target_amount']! as num).toDouble(),
      savedAmount: (map['saved_amount']! as num).toDouble(),
      category: map['category'] as String? ?? 'Tasarruf',
      targetDate: map['target_date'] != null
          ? DateTime.parse(map['target_date']! as String)
          : null,
      note: map['note'] as String?,
      colorHex: map['color_hex'] as String?,
    );
  }
}
