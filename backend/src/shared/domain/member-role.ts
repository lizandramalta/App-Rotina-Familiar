/**
 * Member roles within a family as defined in backend architecture and contracts.
 */
export const MemberRole = {
  ADMINISTRATOR: 'administrator',
  MEMBER: 'member',
  KIDS: 'kids',
} as const;

export type MemberRole = (typeof MemberRole)[keyof typeof MemberRole];

export function isValidMemberRole(role: string): role is MemberRole {
  return Object.values(MemberRole).includes(role as MemberRole);
}
