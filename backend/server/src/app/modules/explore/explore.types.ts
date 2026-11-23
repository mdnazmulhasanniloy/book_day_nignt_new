import { TExploreQuery, TExploreDetailQuery, TExploreFeedQuery, TExploreMapQuery } from './explore.schema';

export interface IExploreListService {
  query: TExploreQuery;
  userId?: string;
  /** Clock override for tests; defaults to the current time. */
  now?: Date;
}

export interface IExploreDetailService {
  id: string;
  query: TExploreDetailQuery;
  userId?: string;
}

export interface ITrackEventView {
  eventId: string;
  /** Logged-in viewer; only then a personal recent view is kept. */
  userId?: string;
  now?: Date;
}

export interface IExploreFeedService {
  query: TExploreFeedQuery;
  userId?: string;
}

export interface IExploreMapService {
  query: TExploreMapQuery;
  /** Clock override for tests; defaults to the current time. */
  now?: Date;
  /** Pin cap override for tests; defaults to EXPLORE_MAP_MAX_PINS (300). */
  maxPins?: number;
}

/** Lightweight pin of GET /explore/map (T-038). */
export interface IExploreMapPin {
  id: string;
  type: 'CLUB' | 'EVENT';
  name: string;
  lat: number;
  lng: number;
  startAt: string | null;
  thumbnail: string;
  minPrice: number | null;
  distanceKm?: number;
}

export interface IExploreClubEventsService {
  clubId: string;
  page: number;
  limit: number;
  userId?: string;
}

export interface IExploreClubArtistsService {
  clubId: string;
}

export interface ILightweightExploreItem {
  id: string;
  name: string;
  lat: number;
  lng: number;
  location: string;
  type: 'CLUB' | 'EVENT';
  review?: number;
  isVip?: boolean;
  thumbnail: string;
  priceRange?: {
    minPrice: number;
    maxPrice: number;
  };
  price?: number;
  currency: string;
  isWishlist?: boolean;
  distanceKm?: number;
  musicGenres?: string[];
  categoryType?: string;
  followerCount?: number;
  startAt?: Date;
  endAt?: Date;
}
