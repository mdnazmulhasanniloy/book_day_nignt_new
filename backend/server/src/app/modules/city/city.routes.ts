import { Router } from 'express';
import {
  adminListCitiesController,
  createCityController,
  listCitiesController,
  updateCityController,
} from '@/app/modules/city/city.controllers';
import {
  adminListCitiesQuerySchema,
  cityIdParamsSchema,
  createCitySchema,
  listCitiesQuerySchema,
  updateCitySchema,
} from '@/app/modules/city/city.schema';
import {
  validateReqBody,
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';
import {
  checkAdminAccessTokenMiddleware,
  checkAdminExistenceMiddleware,
  checkCsrfTokenMiddleware,
} from '@/app/modules/admin/admin.middlewares';

const router = Router();

// Public: no auth (works without location permission).
router.get('/cities', validateReqQuery(listCitiesQuerySchema), listCitiesController);

// Admin: cookie access token, role ADMIN. Reads need no CSRF; writes need the
// double-submit header (same as /admin/profile and /admin/commission).
router
  .route('/admin/cities')
  .get(
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqQuery(adminListCitiesQuerySchema),
    adminListCitiesController
  )
  .post(
    checkCsrfTokenMiddleware,
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqBody(createCitySchema),
    createCityController
  );

router
  .route('/admin/cities/:id')
  .patch(
    checkCsrfTokenMiddleware,
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqParams(cityIdParamsSchema),
    validateReqBody(updateCitySchema),
    updateCityController
  );

export default router;
