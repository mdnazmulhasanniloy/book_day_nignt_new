import { Router } from 'express';
import {
  followClubController,
  unfollowClubController,
  isFollowingClubController,
  getUserFollowingController,
} from '@/app/modules/follow/follow.controllers';
import {
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';
import {
  followClubParamsSchema,
  getFollowingQuerySchema,
} from '@/app/modules/follow/follow.schema';
import {
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
} from '@/app/modules/auth/auth.middlewares';

const router = Router();

router.post(
  '/clubs/:clubId/follow',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(followClubParamsSchema),
  followClubController
);

router.delete(
  '/clubs/:clubId/follow',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(followClubParamsSchema),
  unfollowClubController
);

router.get(
  '/clubs/:clubId/is-following',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(followClubParamsSchema),
  isFollowingClubController
);

router.get(
  '/me/following',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqQuery(getFollowingQuerySchema),
  getUserFollowingController
);

export default router;
