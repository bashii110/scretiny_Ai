/// SerenityAI — Stress Calculation Algorithm
/// Implements the exact weighted formula specified in the design brief.
class StressCalculator {
  StressCalculator._();

  // ─── Weights ─────────────────────────────────────────────────────────────
  static const double _cameraWeight    = 0.30;
  static const double _voiceWeight     = 0.25;
  static const double _phoneWeight     = 0.20;
  static const double _sleepWeight     = 0.15;
  static const double _checkInWeight   = 0.10;

  // ─── Main algorithm ──────────────────────────────────────────────────────
  /// All inputs are 0–100 where higher = more stress.
  static double calculateFinalStressScore({
    required double cameraHRV,   // 30%
    required double voiceScore,  // 25%
    required double phoneUsage,  // 20%
    required double sleepScore,  // 15%
    required double checkInScore, // 10%
  }) {
    final score =
        (cameraHRV    * _cameraWeight)  +
            (voiceScore   * _voiceWeight)   +
            (phoneUsage   * _phoneWeight)   +
            (sleepScore   * _sleepWeight)   +
            (checkInScore * _checkInWeight);

    return score.clamp(0.0, 100.0);
  }

  // ─── Stress level label ──────────────────────────────────────────────────
  static String getStressLevel(double score) {
    if (score <= 25) return 'low';
    if (score <= 50) return 'medium';
    if (score <= 75) return 'high';
    return 'critical';
  }

  // ─── Sleep quality → stress score (inverted: better sleep = less stress) ─
  /// [sleepQuality] is 1–5, returns 0–100 stress contribution.
  static double sleepQualityToStress(int sleepQuality) {
    // 5 = great sleep = 0 stress, 1 = terrible = 100 stress
    return ((5 - sleepQuality) / 4) * 100;
  }

  // ─── Phone usage → stress score ──────────────────────────────────────────
  /// [usageMinutes] is total screen time today.
  /// Baseline: >4 hours is high stress, <1 hour is low stress.
  static double phoneUsageToStress(int usageMinutes) {
    const maxMinutes = 480; // 8 hours = max stress
    const lowMinutes = 60;  // 1 hour = 0 stress

    if (usageMinutes <= lowMinutes) return 0.0;
    if (usageMinutes >= maxMinutes) return 100.0;

    return ((usageMinutes - lowMinutes) / (maxMinutes - lowMinutes)) * 100;
  }

  // ─── HRV → stress score ───────────────────────────────────────────────────
  /// Higher HRV = less stress. Typical range: 20–100ms.
  /// Returns 0–100 stress score (inverted).
  static double hrvToStress(double hrv) {
    const maxHRV = 100.0;
    const minHRV = 10.0;

    if (hrv >= maxHRV) return 0.0;
    if (hrv <= minHRV) return 100.0;

    return ((maxHRV - hrv) / (maxHRV - minHRV)) * 100;
  }

  // ─── Check-in score ───────────────────────────────────────────────────────
  /// [anxietyLevel], [workStress]: 1–5 (higher = more stress)
  /// [energyLevel], [mentalClarity]: 1–5 (higher = less stress)
  static double checkInToStress({
    required int anxietyLevel,
    required int workStress,
    required int energyLevel,
    required int mentalClarity,
  }) {
    final stressors = anxietyLevel + workStress;
    final protectors = energyLevel + mentalClarity;
    final netStress = stressors - protectors; // -8 to +8
    return ((netStress + 8) / 16) * 100;
  }

  // ─── Recommended action based on level ───────────────────────────────────
  static String getRecommendedAction(String level) {
    switch (level) {
      case 'low':
        return 'Great job! Keep up your healthy habits. Try a gratitude journal today.';
      case 'medium':
        return 'Your stress is moderate. Consider a 5-minute breathing exercise.';
      case 'high':
        return 'High stress detected. We recommend a guided meditation or talking to someone.';
      case 'critical':
        return 'Critical stress levels. Please reach out to a therapist or trusted person.';
      default:
        return 'Take a moment to breathe and check in with yourself.';
    }
  }

  // ─── Weekly average ───────────────────────────────────────────────────────
  static double weeklyAverage(List<double> dailyScores) {
    if (dailyScores.isEmpty) return 0.0;
    final sum = dailyScores.reduce((a, b) => a + b);
    return sum / dailyScores.length;
  }

  // ─── Top triggers from logs ───────────────────────────────────────────────
  static List<String> getTopTriggers(
      List<List<String>> allTriggers, {
        int topN = 5,
      }) {
    final frequency = <String, int>{};
    for (final triggerList in allTriggers) {
      for (final trigger in triggerList) {
        frequency[trigger] = (frequency[trigger] ?? 0) + 1;
      }
    }
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topN).map((e) => e.key).toList();
  }
}