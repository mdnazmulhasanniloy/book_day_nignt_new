import { Router } from 'express';
import {
  getClubPurchaseAvailabilityController,
  createClubPurchaseController,
  createEventPurchaseController,
  createModulePurchaseController,
} from '@/app/modules/purchase/purchase.controllers';
import {
  checkAccountStatus,
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
} from '@/app/modules/auth/auth.middlewares';
import {
  checkClubPurchaseAvailabilityMiddleware,
  checkClubPurchaseIdempotencyMiddleware,
  checkPurchasableClubMiddleware,
  checkEventPurchaseBuyerProfileMiddleware,
  checkEventPurchaseIdempotencyMiddleware,
  checkPurchasableClubPackageMiddleware,
  checkPurchasableEventMiddleware,
  requirePurchaseIdempotencyKeyMiddleware,
} from '@/app/modules/purchase/purchase.middlewares';
import {
  clubAvailabilityQuerySchema,
  createClubPurchaseSchema,
  createEventPurchaseSchema,
  createModulePurchaseSchema,
} from '@/app/modules/purchase/purchase.schema';
import { validateReqBody, validateReqQuery } from '@/app/utils/system.utils';

const router = Router();

router
  .route('/purchase/club/availability')
  .get(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    validateReqQuery(clubAvailabilityQuerySchema),
    checkPurchasableClubMiddleware,
    getClubPurchaseAvailabilityController
  );

router
  .route('/purchase/club')
  .post(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    requirePurchaseIdempotencyKeyMiddleware,
    validateReqBody(createClubPurchaseSchema),
    checkPurchasableClubPackageMiddleware,
    checkClubPurchaseIdempotencyMiddleware,
    checkClubPurchaseAvailabilityMiddleware,
    createClubPurchaseController
  );

router
  .route('/purchase/event')
  .post(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    requirePurchaseIdempotencyKeyMiddleware,
    validateReqBody(createEventPurchaseSchema),
    checkPurchasableEventMiddleware,
    checkEventPurchaseBuyerProfileMiddleware,
    checkEventPurchaseIdempotencyMiddleware,
    createEventPurchaseController
  );

router
  .route('/purchase/module')
  .post(
    checkUserAccessTokenMiddleware,
    checkUserExistenceMiddleware,
    checkAccountStatus,
    requirePurchaseIdempotencyKeyMiddleware,
    validateReqBody(createModulePurchaseSchema),
    createModulePurchaseController
  );

export default router;
