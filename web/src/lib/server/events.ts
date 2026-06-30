import { z } from "zod";

export const CustomerOnboardedSchema = z.object({
  eventType: z.literal("CustomerOnboarded"),
  customerId: z.string(),
  inviteId: z.string(),
  friendlyName: z.string(),
  identityId: z.string(),
  at: z.string(),
});
export type CustomerOnboarded = z.infer<typeof CustomerOnboardedSchema>;

export const InviteCreatedSchema = z.object({
  eventType: z.literal("InviteCreated"),
  inviteId: z.string(),
  source: z.string(),
  at: z.string(),
});
export type InviteCreated = z.infer<typeof InviteCreatedSchema>;

export const InviteDeletedSchema = z.object({
  eventType: z.literal("InviteDeleted"),
  inviteId: z.string(),
  at: z.string(),
});
export type InviteDeleted = z.infer<typeof InviteDeletedSchema>;

export const CustomerStatusChangedSchema = z.object({
  eventType: z.literal("CustomerStatusChanged"),
  customerId: z.string(),
  active: z.boolean(),
  at: z.string(),
});
export type CustomerStatusChanged = z.infer<typeof CustomerStatusChangedSchema>;

export const CrmEventSchema = z.discriminatedUnion("eventType", [
  CustomerOnboardedSchema,
  InviteCreatedSchema,
  InviteDeletedSchema,
  CustomerStatusChangedSchema,
]);
export type CrmEvent = z.infer<typeof CrmEventSchema>;

export const CRM_EVENTS_TOPIC = "crm.events" as const;
