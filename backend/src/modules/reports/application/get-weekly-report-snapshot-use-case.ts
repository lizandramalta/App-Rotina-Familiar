import type { ActorContext } from '../../../shared/application/actor-context.js';
import type { Clock } from '../../../shared/application/clock.js';
import type { TransactionRunner } from '../../../shared/application/transaction-runner.js';
import {
  DependencyUnavailableError,
  DomainError,
  NotFoundError,
  ValidationError,
} from '../../../shared/domain/domain-error.js';
import { MemberRole } from '../../../shared/domain/member-role.js';
import { toLocalDateTime } from '../../family/domain/time-zone.js';
import type { WeeklyReportRepositoryPort } from './weekly-report-repository-port.js';

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function validateDate(value: unknown): string {
  if (typeof value !== 'string' || !DATE_PATTERN.test(value)) {
    throw new ValidationError('The reference date is invalid.', {
      referenceDate: ['DATE_INVALID'],
    });
  }
  const [year, month, day] = value.split('-').map(Number);
  if (
    year === undefined ||
    month === undefined ||
    day === undefined ||
    year < 1 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > new Date(Date.UTC(year, month, 0)).getUTCDate()
  ) {
    throw new ValidationError('The reference date is invalid.', {
      referenceDate: ['DATE_INVALID'],
    });
  }
  return value;
}

function plusDays(date: string, days: number): string {
  const result = new Date(`${date}T00:00:00.000Z`);
  result.setUTCDate(result.getUTCDate() + days);
  return result.toISOString().slice(0, 10);
}

function localDate(instant: Date, timeZoneId: string): string {
  const local = toLocalDateTime(instant, timeZoneId);
  return `${String(local.year).padStart(4, '0')}-${String(local.month).padStart(2, '0')}-${String(local.day).padStart(2, '0')}`;
}

/** SPEC-019 CA-01–04: one confirmed weekly snapshot, scoped to the actor's family. */
export class GetWeeklyReportSnapshotUseCase {
  constructor(
    private readonly deps: {
      readonly repository: WeeklyReportRepositoryPort;
      readonly transactionRunner: TransactionRunner;
      readonly clock: Clock;
    },
  ) {}

  async execute(actor: ActorContext, referenceDate: unknown) {
    if (actor.role === MemberRole.KIDS) {
      throw new DomainError({
        message: 'Kids cannot generate family reports.',
        code: 'INSUFFICIENT_PERMISSIONS',
        statusCode: 403,
      });
    }
    const selected = validateDate(referenceDate);
    try {
      return await this.deps.transactionRunner.forFamily(actor.familyId, async (tx) => {
        const currentRole = await this.deps.repository.findRole(tx, actor.familyId, actor.memberId);
        if (currentRole !== MemberRole.ADMINISTRATOR && currentRole !== MemberRole.MEMBER) {
          throw new DomainError({
            message: 'Family report access is unavailable.',
            code: 'INSUFFICIENT_PERMISSIONS',
            statusCode: 403,
          });
        }
        const family = await this.deps.repository.findFamily(tx, actor.familyId);
        if (!family) throw new NotFoundError('Family not found.');
        const weekday = new Date(`${selected}T00:00:00.000Z`).getUTCDay();
        const startDate = plusDays(selected, -((weekday + 6) % 7));
        const endDate = plusDays(startDate, 6);
        const today = localDate(this.deps.clock.now(), family.timeZoneId);
        const created = localDate(family.createdAt, family.timeZoneId);
        if (startDate > today || endDate < created) {
          throw new ValidationError('The report week is outside the available calendar.', {
            referenceDate: ['DATE_OUT_OF_RANGE'],
          });
        }
        const data = await this.deps.repository.getSnapshot(tx, {
          familyId: actor.familyId,
          startDate,
          endDate,
        });
        const total = data.totalTasks;
        const completed = data.completedTasks;
        const totalWeight = data.members.reduce((sum, member) => sum + member.weight, 0);
        return {
          period: { startDate, endDate },
          timeZoneId: family.timeZoneId,
          isTransition: data.isTransition,
          generatedAt: this.deps.clock.now().toISOString(),
          isPartial: endDate > today,
          progress: {
            total,
            completed,
            percentage: total === 0 ? null : (completed / total) * 100,
          },
          load: { totalWeight },
          members: data.members.map((member) => ({
            memberId: member.memberId,
            displayName: member.displayName,
            weight: member.weight,
            completedTasks: member.completedTasks,
            percentage: totalWeight === 0 ? null : (member.weight / totalWeight) * 100,
          })),
        };
      });
    } catch (error) {
      if (error instanceof DomainError) throw error;
      throw new DependencyUnavailableError();
    }
  }
}
