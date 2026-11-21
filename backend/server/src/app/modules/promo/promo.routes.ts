import { Router } from 'express';
import {
  validatePromoCodeController,
  createPromoCodeController,
  listPromoCodesController,
  updatePromoCodeController,
  deletePromoCodeController,
} from '@/app/modules/promo/promo.controllers';
import {
  validateReqBody,
  validateReqQuery,
  validateReqParams,
} from '@/app/utils/system.utils';
import {
  validatePromoCodeSchema,
  createPromoCodeSchema,
  listPromoQuerySchema,
  promoIdParamsSchema,
  updatePromoCodeSchema,
} from '@/app/modules/promo/promo.schema';
import {
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
} from '@/app/modules/auth/auth.middlewares';

const router = Router();

// Public / Authenticated route to check a code before purchasing
router.post(
  '/promo/validate',
  validateReqBody(validatePromoCodeSchema),
  validatePromoCodeController
);

router.get(
  '/promo',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqQuery(listPromoQuerySchema),
  listPromoCodesController
);

// Admin or authenticated owner can create promo codes
router.post(
  '/promo',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqBody(createPromoCodeSchema),
  createPromoCodeController
);

router.put(
  '/promo/:id',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(promoIdParamsSchema),
  validateReqBody(updatePromoCodeSchema),
  updatePromoCodeController
);

router.delete(
  '/promo/:id',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(promoIdParamsSchema),
  deletePromoCodeController
);

export default router;
