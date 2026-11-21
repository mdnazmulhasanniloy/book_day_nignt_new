import { createHash, createPublicKey } from 'crypto';
import { verify, type JwtPayload } from 'jsonwebtoken';
import logger from '@/app/configs/logger.configs';
import { AuthErrorType } from '@/const';

type ProviderName = 'GOOGLE' | 'APPLE';

type Jwk = JsonWebKey & { kid?: string };

const cache = new Map<string, { keys: Jwk[]; expiresAt: number }>();

const jwksUrl = (provider: ProviderName) =>
  provider === 'GOOGLE'
    ? 'https://www.googleapis.com/oauth2/v3/certs'
    : 'https://appleid.apple.com/auth/keys';

function listEnv(name: string): string[] {
  return (process.env[name] || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
}

function audiencesFor(provider: ProviderName): string[] {
  return listEnv(
    provider === 'GOOGLE'
      ? 'GOOGLE_OAUTH_CLIENT_IDS'
      : 'APPLE_OAUTH_CLIENT_IDS'
  );
}

async function loadKeys(provider: ProviderName): Promise<Jwk[]> {
  const url = jwksUrl(provider);
  const cached = cache.get(url);
  if (cached && cached.expiresAt > Date.now()) return cached.keys;
  const response = await fetch(url);
  if (!response.ok) {
    logger.warn('OAuth JWKS fetch failed', {
      provider,
      status: response.status,
    });
    throw {
      statusCode: 502,
      message: 'Identity provider is unavailable',
      errorType: AuthErrorType.PROVIDER_UNAVAILABLE,
    };
  }
  const body = (await response.json()) as { keys?: Jwk[] };
  const keys = body.keys || [];
  cache.set(url, { keys, expiresAt: Date.now() + 60 * 60 * 1000 });
  return keys;
}

function decodePart(token: string, index: number): Record<string, unknown> {
  const part = token.split('.')[index];
  if (!part) return {};
  try {
    return JSON.parse(
      Buffer.from(part, 'base64url').toString('utf8')
    ) as Record<string, unknown>;
  } catch {
    return {};
  }
}

/**
 * Verifies a Google or Apple identity token. Never trusts a client-supplied email.
 */
export async function verifyOAuthIdToken(input: {
  provider: ProviderName;
  idToken: string;
  nonce?: string;
}): Promise<{ sub: string; email: string | null; name: string | null }> {
  const audiences = audiencesFor(input.provider);
  if (audiences.length === 0) {
    logger.warn('OAuth client IDs are not configured', {
      provider: input.provider,
    });
    throw {
      statusCode: 503,
      message: `${input.provider} sign-in is not configured on this server`,
      errorType: AuthErrorType.PROVIDER_NOT_CONFIGURED,
    };
  }

  const header = decodePart(input.idToken, 0);
  const kid = typeof header.kid === 'string' ? header.kid : '';
  const keys = await loadKeys(input.provider);
  const jwk = keys.find((key) => key.kid === kid);
  if (!jwk) {
    logger.warn('OAuth signing key was not found', {
      provider: input.provider,
      kid,
    });
    throw {
      statusCode: 401,
      message: 'Identity token was rejected',
      errorType: AuthErrorType.INVALID_ID_TOKEN,
    };
  }

  const pem = createPublicKey({ key: jwk, format: 'jwk' }).export({
    type: 'spki',
    format: 'pem',
  });

  let payload: JwtPayload;
  try {
    payload = verify(input.idToken, pem, {
      algorithms: ['RS256'],
      audience: audiences as [string, ...string[]],
      issuer:
        input.provider === 'GOOGLE'
          ? ['accounts.google.com', 'https://accounts.google.com']
          : 'https://appleid.apple.com',
      clockTolerance: 60,
    }) as JwtPayload;
  } catch (error) {
    const reason = error instanceof Error ? error.name : 'Error';
    logger.warn('OAuth identity token rejected', {
      provider: input.provider,
      reason,
    });
    throw {
      statusCode: 401,
      message: 'Identity token was rejected',
      errorType: AuthErrorType.INVALID_ID_TOKEN,
    };
  }

  if (input.provider === 'GOOGLE') {
    if (
      payload.email_verified !== true &&
      payload.email_verified !== 'true'
    ) {
      throw {
        statusCode: 401,
        message: 'Google account email is not verified',
        errorType: AuthErrorType.INVALID_ID_TOKEN,
      };
    }
    const azp = typeof payload.azp === 'string' ? payload.azp : '';
    if (azp) {
      const allowed = new Set([
        ...audiences,
        ...listEnv('GOOGLE_OAUTH_AUTHORIZED_PARTIES'),
      ]);
      if (!allowed.has(azp)) {
        logger.warn('OAuth authorized party was rejected', {
          provider: input.provider,
        });
        throw {
          statusCode: 401,
          message: 'Identity token was rejected',
          errorType: AuthErrorType.INVALID_ID_TOKEN,
        };
      }
    }
  }

  if (typeof payload.nonce === 'string') {
    const hashedNonce = input.nonce
      ? createHash('sha256').update(input.nonce).digest('hex')
      : '';
    if (
      !input.nonce ||
      (payload.nonce !== input.nonce && payload.nonce !== hashedNonce)
    ) {
      throw {
        statusCode: 401,
        message: 'Sign-in nonce did not match',
        errorType: AuthErrorType.NONCE_MISMATCH,
      };
    }
  }

  const sub = typeof payload.sub === 'string' ? payload.sub : '';
  if (!sub) {
    throw {
      statusCode: 401,
      message: 'Identity token has no subject',
      errorType: AuthErrorType.INVALID_ID_TOKEN,
    };
  }

  return {
    sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    name: typeof payload.name === 'string' ? payload.name : null,
  };
}
