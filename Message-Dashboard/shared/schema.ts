import { z } from "zod";

export const messageSchema = z.object({
  id: z.number(),
  source: z.string(),
  text: z.string(),
  createdAt: z.string(),
});

export const messagesResponseSchema = z.object({
  count: z.number(),
  data: z.array(messageSchema),
});

export type Message = z.infer<typeof messageSchema>;
export type MessagesResponse = z.infer<typeof messagesResponseSchema>;