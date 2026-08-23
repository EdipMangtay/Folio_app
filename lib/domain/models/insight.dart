enum InsightTone { positive, neutral, warning }

class Insight {
  const Insight({
    required this.title,
    required this.body,
    required this.metric,
    required this.tone,
  });

  final String title;
  final String body;
  final String metric;
  final InsightTone tone;
}
