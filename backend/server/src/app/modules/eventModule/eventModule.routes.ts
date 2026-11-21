import { Router } from 'express';
import {
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  createEventModuleController,
  deleteEventModuleController,
  duplicateEventModuleController,
  listEventModulesController,
  reorderEventModulesController,
  updateEventModuleController,
} from '@/app/modules/eventModule/eventModule.controllers';
import {
  createEventModuleSchema,
  eventModuleIdParamsSchema,
  eventModuleParamsSchema,
  reorderEventModulesSchema,
  updateEventModuleSchema,
} from '@/app/modules/eventModule/eventModule.schema';
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
  '/event/:eventId/modules',
  ...ownerGuards,
  validateReqParams(eventModuleParamsSchema),
  validateReqBody(createEventModuleSchema),
  createEventModuleController
);

router.get(
  '/event/:eventId/modules',
  ...ownerGuards,
  validateReqParams(eventModuleParamsSchema),
  listEventModulesController
);

router.post(
  '/event/:eventId/modules/reorder',
  ...ownerGuards,
  validateReqParams(eventModuleParamsSchema),
  validateReqBody(reorderEventModulesSchema),
  reorderEventModulesController
);

router.post(
  '/event/:eventId/modules/:id/duplicate',
  ...ownerGuards,
  validateReqParams(eventModuleIdParamsSchema),
  duplicateEventModuleController
);

router.put(
  '/event/:eventId/modules/:id',
  ...ownerGuards,
  validateReqParams(eventModuleIdParamsSchema),
  validateReqBody(updateEventModuleSchema),
  updateEventModuleController
);

router.delete(
  '/event/:eventId/modules/:id',
  ...ownerGuards,
  validateReqParams(eventModuleIdParamsSchema),
  deleteEventModuleController
);

export default router;
