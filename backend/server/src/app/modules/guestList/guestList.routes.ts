import { Router } from 'express';
import {
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  getGuestListController,
  joinGuestListController,
  listGuestListEntriesController,
  updateGuestListEntryController,
  upsertGuestListController,
} from '@/app/modules/guestList/guestList.controllers';
import {
  guestListEntriesQuerySchema,
  guestListEntryParamsSchema,
  guestListEventParamsSchema,
  joinGuestListSchema,
  updateGuestListEntrySchema,
  upsertGuestListSchema,
} from '@/app/modules/guestList/guestList.schema';
import {
  validateReqBody,
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';

const router = Router();

const ownerGuards = [
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
] as const;

router.get(
  '/event/:eventId/guest-list',
  ...ownerGuards,
  validateReqParams(guestListEventParamsSchema),
  getGuestListController
);

router.put(
  '/event/:eventId/guest-list',
  ...ownerGuards,
  validateReqParams(guestListEventParamsSchema),
  validateReqBody(upsertGuestListSchema),
  upsertGuestListController
);

router.post(
  '/event/:eventId/guest-list/join',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(guestListEventParamsSchema),
  validateReqBody(joinGuestListSchema),
  joinGuestListController
);

router.get(
  '/event/:eventId/guest-list/entries',
  ...ownerGuards,
  validateReqParams(guestListEventParamsSchema),
  validateReqQuery(guestListEntriesQuerySchema),
  listGuestListEntriesController
);

router.put(
  '/event/:eventId/guest-list/entries/:id',
  ...ownerGuards,
  validateReqParams(guestListEntryParamsSchema),
  validateReqBody(updateGuestListEntrySchema),
  updateGuestListEntryController
);

export default router;
