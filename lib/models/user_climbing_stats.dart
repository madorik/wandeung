class UserClimbingStats {
  final int totalClimbs;
  final int totalCompleted;
  final int totalInProgress;
  final double completionRate;
  final double inProgressRate;
  final int currentStreak;
  final int monthlyClimbs;

  const UserClimbingStats({
    required this.totalClimbs,
    required this.totalCompleted,
    required this.totalInProgress,
    required this.completionRate,
    required this.inProgressRate,
    required this.currentStreak,
    required this.monthlyClimbs,
  });
}
