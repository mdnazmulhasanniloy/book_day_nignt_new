import { NextFunction, Request, RequestHandler, Response } from 'express';

export interface IMediaGuardChains {
  /** Mobile clients: `Authorization: Bearer <token>`. */
  bearer: RequestHandler[];
  /** Admin dashboard: access-token cookie + CSRF double-submit header. */
  cookie: RequestHandler[];
  /** Name of the admin access-token cookie. */
  cookieName: string;
  /** Called when no credentials are present at all. */
  onMissing: (req: Request, res: Response) => void;
}

const runChain = (
  chain: RequestHandler[],
  req: Request,
  res: Response,
  done: NextFunction
): void => {
  let i = 0;
  const step: NextFunction = (err?: unknown) => {
    if (err !== undefined) return done(err);
    // A middleware that already answered (401/403/...) ends the chain.
    if (res.headersSent || res.writableEnded) return;
    const handler = chain[i++];
    if (!handler) return done();
    try {
      const result = handler(req, res, step) as unknown;
      if (result && typeof (result as Promise<void>).catch === 'function') {
        (result as Promise<void>).catch(step);
      }
    } catch (e) {
      step(e);
    }
  };
  step();
};

/**
 * Picks the auth chain from the credentials the request carries. Never
 * falls through to the handler without a successful chain.
 */
export const createMediaGuard =
  (c: IMediaGuardChains): RequestHandler =>
  (req, res, next) => {
    if (req.headers.authorization) return runChain(c.bearer, req, res, next);
    if (req.cookies?.[c.cookieName]) return runChain(c.cookie, req, res, next);
    return c.onMissing(req, res);
  };
