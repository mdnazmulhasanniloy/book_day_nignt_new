import { Router } from 'express';
import {
  checkAccountStatus,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  followArtistController,
  getMyArtistsController,
  unfollowArtistController,
} from '@/app/modules/artists/artists.controllers';
import {
  artistIdParamsSchema,
  myArtistsQuerySchema,
} from '@/app/modules/artists/artists.schema';
import {
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';

const router = Router();

router.post(
  '/artists/:id/follow',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(artistIdParamsSchema),
  followArtistController
);

router.delete(
  '/artists/:id/follow',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(artistIdParamsSchema),
  unfollowArtistController
);

router.get(
  '/me/artists',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqQuery(myArtistsQuerySchema),
  getMyArtistsController
);

export default router;
