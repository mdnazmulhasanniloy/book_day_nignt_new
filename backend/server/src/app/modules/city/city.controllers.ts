import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  createCityService,
  listCitiesService,
  publicListCitiesService,
  updateCityService,
} from '@/app/modules/city/city.services';
import {
  TAdminListCitiesQuery,
  TCityIdParams,
  TCreateCityBody,
  TListCitiesQuery,
  TUpdateCityBody,
} from '@/app/modules/city/city.schema';

export const listCitiesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = (req.validatedQuery || req.query) as unknown as TListCitiesQuery;
    const { data, meta } = await publicListCitiesService({ query });
    res.status(200).json({
      success: true,
      message: 'Cities retrieved successfully',
      data,
      meta,
      traceId: getTraceId(),
    });
  }
);

export const adminListCitiesController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = (req.validatedQuery || req.query) as unknown as TAdminListCitiesQuery;
    const { data, meta } = await listCitiesService({ query });
    res.status(200).json({
      success: true,
      message: 'Cities retrieved successfully',
      data,
      meta,
      traceId: getTraceId(),
    });
  }
);

export const createCityController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const data = await createCityService({ body: req.body as TCreateCityBody });
    res.status(201).json({
      success: true,
      message: 'City created successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const updateCityController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as unknown as TCityIdParams;
    const data = await updateCityService({ id, body: req.body as TUpdateCityBody });
    res.status(200).json({
      success: true,
      message: 'City updated successfully',
      data,
      traceId: getTraceId(),
    });
  }
);
