/**
 * Clock abstraction to allow deterministic testing and controlled time progression.
 */
export interface Clock {
  now(): Date;
  nowIsoString(): string;
}

export class SystemClock implements Clock {
  public now(): Date {
    return new Date();
  }

  public nowIsoString(): string {
    return this.now().toISOString();
  }
}
