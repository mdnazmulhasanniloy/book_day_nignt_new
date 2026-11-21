import { Router } from 'express';
import {
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  createQuoteController,
  listQuotesController,
  updateQuoteController,
} from '@/app/modules/quotes/quotes.controllers';
import {
  createQuoteSchema,
  listQuotesQuerySchema,
  quoteIdParamsSchema,
  updateQuoteSchema,
} from '@/app/modules/quotes/quotes.schema';
import {
  validateReqBody,
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';

const router = Router();

router.post(
  '/quotes',
  validateReqBody(createQuoteSchema),
  createQuoteController
);

router.get(
  '/quotes',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  validateReqQuery(listQuotesQuerySchema),
  listQuotesController
);

router.put(
  '/quotes/:id',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  checkClubOwnerRoleMiddleware,
  validateReqParams(quoteIdParamsSchema),
  validateReqBody(updateQuoteSchema),
  updateQuoteController
);

export default router;
