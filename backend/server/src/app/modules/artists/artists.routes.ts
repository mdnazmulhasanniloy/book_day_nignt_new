import { Router } from 'express';
import {
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  optionalUserAccessTokenMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  checkAdminAccessTokenMiddleware,
  checkAdminExistenceMiddleware,
  checkCsrfTokenMiddleware,
} from '@/app/modules/admin/admin.middlewares';
import {
  adminListArtistsController,
  adminUpdateArtistController,
  followArtistController,
  getArtistProfileController,
  getMyArtistsController,
  listArtistsController,
  ownerUpdateArtistController,
  unfollowArtistController,
} from '@/app/modules/artists/artists.controllers';
import {
  adminListArtistsQuerySchema,
  adminUpdateArtistSchema,
  artistIdParamsSchema,
  listArtistsQuerySchema,
  myArtistsQuerySchema,
  ownerUpdateArtistSchema,
} from '@/app/modules/artists/artists.schema';
import {
  validateReqBody,
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

// T-044 (CR-12). Public reads: optional bearer (isFollowing only with a token).
router.get(
  '/artists',
  optionalUserAccessTokenMiddleware,
  validateReqQuery(listArtistsQuerySchema),
  listArtistsController
);

router.get(
  '/artists/:id',
  optionalUserAccessTokenMiddleware,
  validateReqParams(artistIdParamsSchema),
  getArtistProfileController
);

// Club owner who has the artist in the lineup of one of their events.
router.patch(
  '/artists/:id',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  validateReqParams(artistIdParamsSchema),
  validateReqBody(ownerUpdateArtistSchema),
  ownerUpdateArtistController
);

// Admin: cookie access token, role ADMIN; writes need the CSRF double-submit header.
router.get(
  '/admin/artists',
  checkAdminAccessTokenMiddleware,
  checkAdminExistenceMiddleware,
  validateReqQuery(adminListArtistsQuerySchema),
  adminListArtistsController
);

router.patch(
  '/admin/artists/:id',
  checkCsrfTokenMiddleware,
  checkAdminAccessTokenMiddleware,
  checkAdminExistenceMiddleware,
  validateReqParams(artistIdParamsSchema),
  validateReqBody(adminUpdateArtistSchema),
  adminUpdateArtistController
);

export default router;
