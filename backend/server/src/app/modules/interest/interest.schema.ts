import { z } from 'zod';

export const interestParamsSchema = z.object({
  eventId: z.string().uuid(),
});
