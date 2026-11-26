import { Router } from 'express';
import {
  createFilterOptionController,
  listFilterOptionsController,
  updateFilterOptionController,
} from '@/app/modules/filterOption/filterOption.controllers';
import {
  adminListFilterOptionsQuerySchema,
  createFilterOptionSchema,
  filterOptionIdParamsSchema,
  updateFilterOptionSchema,
} from '@/app/modules/filterOption/filterOption.schema';
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

// The public GET /explore/filters lives in explore.routes.ts (it must be
// registered before /explore/:id).
const router = Router();

// Admin: cookie access token, role ADMIN. Reads need no CSRF; writes need the
// double-submit header (same as /admin/cities).
router
  .route('/admin/filter-options')
  .get(
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqQuery(adminListFilterOptionsQuerySchema),
    listFilterOptionsController
  )
  .post(
    checkCsrfTokenMiddleware,
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqBody(createFilterOptionSchema),
    createFilterOptionController
  );

router
  .route('/admin/filter-options/:id')
  .patch(
    checkCsrfTokenMiddleware,
    checkAdminAccessTokenMiddleware,
    checkAdminExistenceMiddleware,
    validateReqParams(filterOptionIdParamsSchema),
    validateReqBody(updateFilterOptionSchema),
    updateFilterOptionController
  );

export default router;
