import { Request, Response } from 'express';
import { getTraceId } from '@/app/configs/requestContext.configs';
import { asyncHandler } from '@/app/utils/system.utils';
import {
  createFilterOptionService,
  exploreFiltersService,
  listFilterOptionsService,
  updateFilterOptionService,
} from '@/app/modules/filterOption/filterOption.services';
import {
  TAdminListFilterOptionsQuery,
  TCreateFilterOptionBody,
  TExploreFiltersQuery,
  TFilterOptionIdParams,
  TUpdateFilterOptionBody,
} from '@/app/modules/filterOption/filterOption.schema';

export const exploreFiltersController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = (req.validatedQuery || req.query) as unknown as TExploreFiltersQuery;
    const data = await exploreFiltersService({ query });
    res.status(200).json({
      success: true,
      message: 'Filters retrieved successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const listFilterOptionsController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const query = (req.validatedQuery ||
      req.query) as unknown as TAdminListFilterOptionsQuery;
    const data = await listFilterOptionsService({ query });
    res.status(200).json({
      success: true,
      message: 'Filter options retrieved successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const createFilterOptionController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const data = await createFilterOptionService({
      body: req.body as TCreateFilterOptionBody,
    });
    res.status(201).json({
      success: true,
      message: 'Filter option created successfully',
      data,
      traceId: getTraceId(),
    });
  }
);

export const updateFilterOptionController = asyncHandler(
  async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as unknown as TFilterOptionIdParams;
    const data = await updateFilterOptionService({
      id,
      body: req.body as TUpdateFilterOptionBody,
    });
    res.status(200).json({
      success: true,
      message: 'Filter option updated successfully',
      data,
      traceId: getTraceId(),
    });
  }
);
