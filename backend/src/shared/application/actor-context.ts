import { MemberRole } from '../domain/member-role.js';

/**
 * Context of the authenticated actor making the request.
 *
 * Populated by presentation/transport middleware from session authentication
 * and passed into application use cases.
 */
export interface ActorContext {
  readonly sessionId: string;
  readonly familyId: string;
  readonly memberId: string;
  readonly role: MemberRole;
  readonly isFamilyCreator: boolean;
  readonly installationId?: string;
}
