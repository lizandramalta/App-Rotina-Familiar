import { describe, expect, it } from 'vitest';
import { selectWeeklyWinners } from '../../src/modules/recognition/domain/weekly-winners.js';

describe('SPEC-020 CA-02 — weekly winners', () => {
  it('recognizes all positive ties by weight, regardless of task count', () => {
    const scores = [
      { memberId: 'adult', points: 6, completedTasks: 2 },
      { memberId: 'kid', points: 6, completedTasks: 6 },
      { memberId: 'other', points: 5, completedTasks: 5 },
    ];
    expect(selectWeeklyWinners(scores)).toEqual(scores.slice(0, 2));
  });
  it('does not invent a winner without positive credits', () => {
    expect(selectWeeklyWinners([])).toEqual([]);
    expect(selectWeeklyWinners([{ memberId: 'adult', points: 0, completedTasks: 0 }])).toEqual([]);
  });
});
