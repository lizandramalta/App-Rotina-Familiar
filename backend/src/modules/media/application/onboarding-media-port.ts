import type { TransactionContext } from '../../../shared/application/transaction-runner.js';

export interface OnboardingMediaRecord {
  readonly id: string;
  readonly grantId: string;
  readonly purpose: string;
  readonly state: string;
  readonly objectKey: string;
  readonly sizeBytes: number | null;
  readonly contentType: string | null;
}

export interface OnboardingMediaPort {
  findUsableGrant(
    tx: TransactionContext,
    tokenHash: string,
    installationProofHash: string,
    now: Date,
  ): Promise<string | undefined>;
  reserve(
    tx: TransactionContext,
    input: { id: string; grantId: string; objectKey: string },
  ): Promise<void>;
  markReady(
    tx: TransactionContext,
    input: { id: string; sizeBytes: number; contentType: string },
  ): Promise<void>;
  markFailed(tx: TransactionContext, id: string): Promise<void>;
  findForGrant(
    tx: TransactionContext,
    id: string,
    grantId: string,
  ): Promise<OnboardingMediaRecord | undefined>;
  findById(tx: TransactionContext, id: string): Promise<OnboardingMediaRecord | undefined>;
  transferToCreator(
    tx: TransactionContext,
    input: { media: OnboardingMediaRecord; familyId: string; memberId: string; now: Date },
  ): Promise<void>;
  claimExpired(
    tx: TransactionContext,
    before: Date,
    limit: number,
  ): Promise<readonly OnboardingMediaRecord[]>;
  deleteClaimed(tx: TransactionContext, id: string): Promise<void>;
}
