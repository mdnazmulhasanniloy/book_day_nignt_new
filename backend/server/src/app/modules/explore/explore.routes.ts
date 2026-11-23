import { Router } from 'express';
import {
  exploreListController,
  exploreDetailController,
  exploreFeedController,
  exploreGenresController,
  exploreClubUpcomingEventsController,
  exploreClubPastEventsController,
  exploreClubArtistsController,
} from '@/app/modules/explore/explore.controllers';
import {
  exploreQuerySchema,
  exploreDetailQuerySchema,
  exploreIdParamsSchema,
  exploreFeedQuerySchema,
  explorePaginationQuerySchema,
} from '@/app/modules/explore/explore.schema';
import { validateReqQuery, validateReqParams } from '@/app/utils/system.utils';
import { exploreFiltersController } from '@/app/modules/filterOption/filterOption.controllers';
import { exploreFiltersQuerySchema } from '@/app/modules/filterOption/filterOption.schema';
import { optionalUserAccessTokenMiddleware } from '@/app/modules/auth/auth.middlewares';

const router = Router();

router.get(
  '/explore',
  optionalUserAccessTokenMiddleware,
  validateReqQuery(exploreQuerySchema),
  exploreListController
);

router.get(
  '/explore/feed',
  optionalUserAccessTokenMiddleware,
  validateReqQuery(exploreFeedQuerySchema),
  exploreFeedController
);

// Public vocabulary (T-037). Registered before /explore/:id.
router.get(
  '/explore/filters',
  validateReqQuery(exploreFiltersQuerySchema),
  exploreFiltersController
);

router.get(
  '/explore/genres',
  exploreGenresController
);

router.get(
  '/explore/club/:id/events/upcoming',
  optionalUserAccessTokenMiddleware,
  validateReqParams(exploreIdParamsSchema),
  validateReqQuery(explorePaginationQuerySchema),
  exploreClubUpcomingEventsController
);

router.get(
  '/explore/club/:id/events/past',
  optionalUserAccessTokenMiddleware,
  validateReqParams(exploreIdParamsSchema),
  validateReqQuery(explorePaginationQuerySchema),
  exploreClubPastEventsController
);

router.get(
  '/explore/club/:id/artists',
  validateReqParams(exploreIdParamsSchema),
  exploreClubArtistsController
);

router.get(
  '/explore/:id',
  optionalUserAccessTokenMiddleware,
  validateReqParams(exploreIdParamsSchema),
  validateReqQuery(exploreDetailQuerySchema),
  exploreDetailController
);

export default router;
