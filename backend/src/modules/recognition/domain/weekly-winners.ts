export interface WeeklyScore {
  readonly memberId: string;
  readonly points: number;
  readonly completedTasks: number;
}

/** RN30/RN65: quantidade é informativa; todos os maiores positivos são reconhecidos. */
export function selectWeeklyWinners(scores: readonly WeeklyScore[]): readonly WeeklyScore[] {
  const highest = scores.reduce((max, score) => Math.max(max, score.points), 0);
  return highest > 0 ? scores.filter((score) => score.points === highest) : [];
}
