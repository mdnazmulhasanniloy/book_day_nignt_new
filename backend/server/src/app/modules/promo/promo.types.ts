import { DiscountType } from '@prisma/client';
import {
  TListPromoQuery,
  TUpdatePromoCodePayload,
} from '@/app/modules/promo/promo.schema';

export interface IValidatePromoCodeParams {
  code: string;
  originalAmount: number;
  eventId?: string;
  clubId?: string;
}

export interface IValidatePromoCodeResponse {
  isValid: boolean;
  code: string;
  discountType: DiscountType;
  discountValue: number;
  discountAmount: number;
  finalAmount: number;
}

export interface ICreatePromoCodeParams {
  userId: string;
  code: string;
  discountType: DiscountType;
  discountValue: number;
  eventId?: string;
  clubId?: string;
  maxUses?: number;
  expiresAt?: Date;
}

export interface IListPromoCodesParams {
  userId: string;
  query: TListPromoQuery;
}

export interface IUpdatePromoCodeParams {
  id: string;
  userId: string;
  payload: TUpdatePromoCodePayload;
}

export interface IDeletePromoCodeParams {
  id: string;
  userId: string;
}
