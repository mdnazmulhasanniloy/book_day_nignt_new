import { Router } from 'express';
import {
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  optionalUserAccessTokenMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  attachHostToClubController,
  attachHostToEventController,
  contactHostController,
  createHostController,
  deleteHostController,
  listEventHostInquiriesController,
  listEventHostsController,
  listHostsController,
  unassignHostFromEventController,
  updateHostController,
} from '@/app/modules/hosts/hosts.controllers';
import {
  attachHostSchema,
  clubHostParamsSchema,
  createHostSchema,
  eventHostParamsSchema,
  eventHostUnassignParamsSchema,
  hostContactSchema,
  hostIdParamsSchema,
  updateHostSchema,
} from '@/app/modules/hosts/hosts.schema';
import {
  validateReqBody,
  validateReqParams,
} from '@/app/utils/system.utils';

const router = Router();

const ownerGuards = [
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
] as const;

router.post(
  '/hosts',
  ...ownerGuards,
  validateReqBody(createHostSchema),
  createHostController
);

router.get(
  '/hosts',
  ...ownerGuards,
  listHostsController
);

router.put(
  '/hosts/:id',
  ...ownerGuards,
  validateReqParams(hostIdParamsSchema),
  validateReqBody(updateHostSchema),
  updateHostController
);

router.delete(
  '/hosts/:id',
  ...ownerGuards,
  validateReqParams(hostIdParamsSchema),
  deleteHostController
);

router.post(
  '/hosts/:id/contact',
  optionalUserAccessTokenMiddleware,
  validateReqParams(hostIdParamsSchema),
  validateReqBody(hostContactSchema),
  contactHostController
);

router.get(
  '/event/:eventId/host-inquiries',
  ...ownerGuards,
  validateReqParams(eventHostParamsSchema),
  listEventHostInquiriesController
);

router.get(
  '/event/:eventId/hosts',
  ...ownerGuards,
  validateReqParams(eventHostParamsSchema),
  listEventHostsController
);

router.post(
  '/event/:eventId/hosts',
  ...ownerGuards,
  validateReqParams(eventHostParamsSchema),
  validateReqBody(attachHostSchema),
  attachHostToEventController
);

router.delete(
  '/event/:eventId/hosts/:hostId',
  ...ownerGuards,
  validateReqParams(eventHostUnassignParamsSchema),
  unassignHostFromEventController
);

router.post(
  '/club/:clubId/hosts',
  ...ownerGuards,
  validateReqParams(clubHostParamsSchema),
  validateReqBody(attachHostSchema),
  attachHostToClubController
);

export default router;
