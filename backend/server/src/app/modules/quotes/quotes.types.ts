import {
  TCreateQuotePayload,
  TListQuotesQuery,
  TUpdateQuotePayload,
} from '@/app/modules/quotes/quotes.schema';

export interface ICreateQuoteService {
  payload: TCreateQuotePayload;
}

export interface IListQuotesService {
  ownerUserId: string;
  query: TListQuotesQuery;
}

export interface IUpdateQuoteService {
  ownerUserId: string;
  quoteId: string;
  payload: TUpdateQuotePayload;
}
