-- Guest list owner decision push notification types
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'GUEST_LIST_CONFIRMED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'GUEST_LIST_REJECTED';
