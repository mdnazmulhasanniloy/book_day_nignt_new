import { Router } from 'express';
import {
  addInterestController,
  removeInterestController,
} from '@/app/modules/interest/interest.controllers';
import { interestParamsSchema } from '@/app/modules/interest/interest.schema';
import { validateReqParams } from '@/app/utils/system.utils';
import {
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
} from '@/app/modules/auth/auth.middlewares';

const router = Router();

// CR-11 (T-040). Count only: there is deliberately NO route that lists the
// interested users (client decision Q6d). Do not add one without a new decision.
router.post(
  '/events/:eventId/interested',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(interestParamsSchema),
  addInterestController
);

router.delete(
  '/events/:eventId/interested',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(interestParamsSchema),
  removeInterestController
);

export default router;
