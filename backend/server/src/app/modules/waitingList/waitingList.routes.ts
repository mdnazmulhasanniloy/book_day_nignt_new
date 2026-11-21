import { Router } from 'express';
import {
  joinWaitingListController,
  leaveWaitingListController,
  getMyWaitingListController,
  getClubWaitingListStatusController,
  getClubWaitingListMembersController,
  notifyWaitingListEntryController,
  deleteWaitingListEntryController,
} from '@/app/modules/waitingList/waitingList.controllers';
import {
  joinWaitingListSchema,
  leaveWaitingListSchema,
  clubWaitingListStatusParamsSchema,
  clubWaitingListMembersParamsSchema,
  myWaitingListQuerySchema,
  clubWaitingListMembersQuerySchema,
  waitingListEntryParamsSchema,
} from '@/app/modules/waitingList/waitingList.schema';
import {
  validateReqBody,
  validateReqParams,
  validateReqQuery,
} from '@/app/utils/system.utils';
import {
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
} from '@/app/modules/auth/auth.middlewares';

const router = Router();

router.post(
  '/waiting-list/join',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqBody(joinWaitingListSchema),
  joinWaitingListController
);

router.post(
  '/waiting-list/leave',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqBody(leaveWaitingListSchema),
  leaveWaitingListController
);

router.get(
  '/waiting-list/my',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqQuery(myWaitingListQuerySchema),
  getMyWaitingListController
);

router.get(
  '/waiting-list/club/:clubId/status',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(clubWaitingListStatusParamsSchema),
  getClubWaitingListStatusController
);

router.get(
  '/waiting-list/club/:clubId',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(clubWaitingListMembersParamsSchema),
  validateReqQuery(clubWaitingListMembersQuerySchema),
  getClubWaitingListMembersController
);

router.post(
  '/waiting-list/:id/notify',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(waitingListEntryParamsSchema),
  notifyWaitingListEntryController
);

router.delete(
  '/waiting-list/:id',
  checkUserAccessTokenMiddleware,
  checkUserExistenceMiddleware,
  checkAccountStatus,
  validateReqParams(waitingListEntryParamsSchema),
  deleteWaitingListEntryController
);

export default router;
